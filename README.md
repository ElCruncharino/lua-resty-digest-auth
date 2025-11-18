# lua-resty-digest-auth

[![Build Status](https://github.com/ElCruncharino/lua-resty-digest-auth/workflows/Test/badge.svg)](https://github.com/ElCruncharino/lua-resty-digest-auth/actions)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![OpenResty](https://img.shields.io/badge/OpenResty-1.19.9+-green.svg)](https://openresty.org/)
[![OPM](https://img.shields.io/badge/OPM-Available-orange.svg)](https://opm.openresty.org/)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/f3ea099843f9455a9f95bf16b79f1fb8)](https://app.codacy.com/gh/ElCruncharino/lua-resty-digest-auth/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

An OpenResty module implementing RFC 2617 HTTP Digest Authentication with brute force protection, rate limiting, and suspicious pattern detection.

## Features

- RFC 2617 compliant HTTP Digest Authentication
- Brute force protection with configurable thresholds
- Rate limiting per client IP
- Suspicious pattern detection (empty credentials, malformed headers, rapid requests)
- Username enumeration protection
- Optimized nonce management with configurable reuse limits
- Shared memory support across Nginx workers
- Simple configuration with sensible defaults

## Installation

### Via OPM

```bash
opm get ElCruncharino/lua-resty-digest-auth
```

### Manual Installation

```bash
git clone https://github.com/ElCruncharino/lua-resty-digest-auth.git
cd lua-resty-digest-auth
make install
```

### Docker Testing

```bash
cd test
docker-compose up --build
curl -u alice:password123 http://localhost:8080/protected/
```

## Quick Start

### 1. Create User Credentials

Create a file (e.g., `htdigest`) with user credentials:
```
username:realm:HA1_hash
```

Generate HA1 hash: `echo -n "username:realm:password" | md5sum`

### 2. Configure Nginx

```nginx
# Define shared memory
lua_shared_dict digest_auth 2m;
lua_shared_dict digest_auth_ratelimit 1m;

# Initialize the module
init_by_lua_block {
    local DigestAuth = require "resty.digest_auth"

    local ok, err = DigestAuth.configure {
        shared_memory_name = "digest_auth",
        credentials_file = "/path/to/htdigest",
        realm = "My Protected Area",
        brute_force = {
            enabled = true,
            max_failed_attempts = 5,
            window_seconds = 300,
            block_seconds = 1800
        }
    }

    if not ok then
        error("Failed to configure digest auth: " .. (err or "unknown error"))
    end
}

server {
    listen 80;
    server_name example.com;

    # Protected endpoint
    location /protected/ {
        access_by_lua_block {
            local DigestAuth = require "resty.digest_auth"
            DigestAuth.require_auth()
        }

        return 200 "Protected content!";
    }
}
```

## Configuration

### Basic Configuration

```lua
DigestAuth.configure {
    shared_memory_name = "digest_auth",     -- Required: shared memory name
    credentials_file = "/path/to/htdigest", -- Required: user credentials file
    realm = "Protected Area",               -- Optional: authentication realm
    nonce_lifetime = 600,                   -- Optional: nonce validity (seconds)
    max_nonce_uses = 500,                   -- Optional: max nonce reuses
    refresh_threshold = 80,                 -- Optional: refresh at % usage
}
```

### Advanced Security Configuration

```lua
DigestAuth.configure {
    shared_memory_name = "digest_auth",
    credentials_file = "/path/to/htdigest",
    realm = "Secure Area",

    -- Rate limiting
    rate_limit = {
        enabled = true,
        max_attempts = 10,
        window_seconds = 300,
        block_seconds = 60
    },

    -- Brute force protection
    brute_force = {
        enabled = true,
        max_failed_attempts = 5,
        window_seconds = 300,
        block_seconds = 1800,
        suspicious_patterns = {
            common_passwords = {"password", "123456", "admin", "root", "test"},
            empty_credentials = true,
            malformed_headers = true,
            rapid_requests = 5,
            username_enumeration = 3
        }
    }
}
```

## API Reference

### `DigestAuth.configure(options)`

Configures the module. Must be called before using authentication.

**Parameters:**
- `options` (table): Configuration options

**Returns:**
- `ok` (boolean): `true` on success, `false` on failure
- `err` (string): Error message if failed

### `DigestAuth.require_auth()`

Requires authentication for the current request. Exits with appropriate HTTP status codes.

**Returns:**
- Exits with `ngx.OK` (200) if authenticated
- Exits with `ngx.HTTP_UNAUTHORIZED` (401) if authentication required
- Exits with `ngx.HTTP_FORBIDDEN` (403) if rate limited or blocked
- Exits with `ngx.HTTP_BAD_REQUEST` (400) if malformed request

### `DigestAuth.clear_memory()`

Clears all shared memory used by the module.

### `DigestAuth.clear_nonces()`

Clears only nonce-related entries from shared memory.

### `DigestAuth.cleanup_expired_nonces()`

Cleans up expired nonce entries. Call this periodically (e.g., via a timer) to prevent memory exhaustion in high-traffic environments.

## Security Features

### Brute Force Protection
- Tracks failed authentication attempts per client IP
- Blocks clients after configurable failed attempts
- Detects suspicious patterns (empty credentials, malformed headers, rapid requests)
- Prevents username enumeration attacks
- Configurable blocking durations and thresholds

### Rate Limiting
- Per-client IP tracking
- Configurable time windows and attempt limits
- Automatic recovery after timeout period

### Monitoring & Logging
- Enhanced logging with separate auth and security formats
- Security event tracking
- Health check endpoints

## Examples

### Basic Protection

```nginx
location /api/ {
    access_by_lua_block {
        local DigestAuth = require "resty.digest_auth"
        DigestAuth.require_auth()
    }

    # Your API content
}
```

### Multiple Realms

```nginx
init_by_lua_block {
    local DigestAuth = require "resty.digest_auth"

    local ok, err = DigestAuth.configure {
        shared_memory_name = "admin_auth",
        credentials_file = "/etc/nginx/admin_users",
        realm = "Admin Area",
        brute_force = { enabled = true, max_failed_attempts = 3 }
    }

    if not ok then error("Admin auth setup failed: " .. err) end
}

location /admin/ {
    access_by_lua_block {
        local DigestAuth = require "resty.digest_auth"
        DigestAuth.require_auth()
    }
}
```

### Production Configuration

```nginx
# Enhanced logging
log_format auth '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for" '
                'auth_user="$http_authorization"';

log_format security '$remote_addr - [$time_local] "$request" '
                    '$status "$http_user_agent" '
                    'event="$sent_http_x_security_event" '
                    'reason="$sent_http_x_block_reason"';

access_log /var/log/nginx/auth.log auth;
access_log /var/log/nginx/security.log security;

# Shared memory
lua_shared_dict digest_auth 4m;
lua_shared_dict digest_auth_ratelimit 2m;

init_by_lua_block {
    local DigestAuth = require "resty.digest_auth"

    local ok, err = DigestAuth.configure {
        shared_memory_name = "digest_auth",
        credentials_file = "/etc/nginx/htdigest",
        realm = "Secure Area",
        nonce_lifetime = 300,
        max_nonce_uses = 100,
        rate_limit = {
            enabled = true,
            max_attempts = 10,
            window_seconds = 300,
            block_seconds = 60
        },
        brute_force = {
            enabled = true,
            max_failed_attempts = 5,
            window_seconds = 300,
            block_seconds = 1800,
            suspicious_patterns = {
                common_passwords = {"password", "123456", "admin", "root", "test"},
                empty_credentials = true,
                malformed_headers = true,
                rapid_requests = 5,
                username_enumeration = 3
            }
        }
    }

    if not ok then
        error("Failed to configure digest auth: " .. (err or "unknown error"))
    end
}
```

## Testing

The module includes several test scripts:

### Docker Testing (Recommended)
```bash
cd test
docker-compose up --build
curl --digest -u alice:password123 http://localhost:8080/protected/
```

### Native Linux Testing
```bash
cd test
chmod +x setup_linux.sh
./setup_linux.sh
start_test_server
test_digest_auth
```

## User Credentials File

The credentials file should contain one entry per line in the format:
```
username:realm:HA1_hash
```

### Generating Credentials

**Using OpenSSL:**
```bash
echo -n "username:realm:password" | openssl md5
```

**Using MD5sum:**
```bash
echo -n "username:realm:password" | md5sum
```

**Using Python:**
```python
import hashlib
print(hashlib.md5("username:realm:password".encode()).hexdigest())
```

**Example:**
```bash
# For user "alice" with password "password123" in realm "Test Realm"
echo -n "alice:Test Realm:password123" | md5sum
# Result: 49e8d18599d46ed533eb6f4ca0325170
```

## Troubleshooting

### Common Issues

1. **"shared_memory_name not found"**: Ensure shared memory is defined in nginx.conf
2. **"credentials_file not found"**: Check file path and permissions
3. **"No valid users found"**: Verify credentials file format
4. **Authentication failures**: Check realm matches between config and credentials file

### Debug Logging

Enable debug logging:
```nginx
error_log /var/log/nginx/error.log debug;
```

### Memory Issues

Increase shared memory allocation:
```nginx
lua_shared_dict digest_auth 8m;  # Increase from 2m to 8m
```

## Monitoring

### Health Checks
```bash
# Check module status
curl -f http://your-domain.com/health

# Check authentication
curl --digest -u username:password http://your-domain.com/protected/
```

### Log Analysis
```bash
# Failed authentication attempts
grep "403\|401" /var/log/nginx/auth.log

# Brute force attempts
grep "brute_force" /var/log/nginx/error.log

# Rate limiting events
grep "rate_limit" /var/log/nginx/error.log
```

## Contributing

Pull requests are welcome. Please include tests for any new features or bug fixes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Issues: [GitHub Issues](https://github.com/ElCruncharino/lua-resty-digest-auth/issues)
- Documentation: [Test Documentation](test/README.md)

---

## Security Hardening

This module includes additional security mitigations beyond standard Digest Auth:
- Header name and value sanitization and length checks
- Shared memory key sanitization
- Log value sanitization
- Credential file path validation (absolute paths, no path traversal)
- Constant-time string comparison for authentication
- Utility for periodic nonce cleanup

These mitigations reduce the risk of memory exhaustion, log injection, timing attacks, and key collisions.
