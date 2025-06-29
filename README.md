# lua-resty-digest-auth

[![Build Status](https://github.com/ElCruncharino/lua-resty-digest-auth/workflows/Test/badge.svg)](https://github.com/ElCruncharino/lua-resty-digest-auth/actions)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![OpenResty](https://img.shields.io/badge/OpenResty-1.19.9+-green.svg)](https://openresty.org/)
[![OPM](https://img.shields.io/badge/OPM-Available-orange.svg)](https://opm.openresty.org/)

A modern, production-ready OpenResty module for HTTP Digest Authentication with advanced security features including brute force protection, rate limiting, and suspicious pattern detection.

## 🚀 Features

- **🔐 RFC 2617 Compliant**: Full HTTP Digest Authentication implementation
- **🛡️ Advanced Security**: Built-in brute force protection and rate limiting
- **⚡ High Performance**: Optimized nonce management with configurable reuse limits
- **🔍 Suspicious Pattern Detection**: Detects and blocks common attack patterns
- **📊 Comprehensive Monitoring**: Enhanced logging and health check endpoints
- **🎯 Simple Setup**: One-line configuration with sensible defaults
- **🔄 Shared Memory**: Efficient nonce storage across workers
- **📝 Modern API**: Clean, intuitive interface designed for ease of use

## 📦 Installation

### Via OPM (Recommended)

```bash
opm get ElCruncharino/lua-resty-digest-auth
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/ElCruncharino/lua-resty-digest-auth.git
cd lua-resty-digest-auth

# Install the module
make install
```

### Docker Testing

```bash
# Test with Docker (recommended for development)
cd test
docker-compose up --build
curl -u alice:password123 http://localhost:8080/protected/
```

## 🚀 Quick Start

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

That's it! Your endpoint is now protected with advanced digest authentication.

## 🔧 Configuration

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

## 📚 API Reference

### `DigestAuth.configure(options)`

Configures the module with the specified options. Must be called before using authentication.

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

Cleans up expired nonce entries from shared memory. Call this periodically (e.g., via a timer) to prevent memory exhaustion in high-traffic environments.

## 🔒 Security Features

### Brute Force Protection
- **Failed Attempt Tracking**: Blocks clients after configurable failed attempts
- **Suspicious Pattern Detection**: Detects empty credentials, malformed headers, rapid requests
- **Username Enumeration Protection**: Prevents username discovery attacks
- **Configurable Blocking**: Adjustable block durations and thresholds

### Rate Limiting
- **Per-Client Tracking**: Individual IP monitoring
- **Configurable Windows**: Adjustable time windows and attempt limits
- **Automatic Recovery**: Clients unblocked after timeout period

### Monitoring & Logging
- **Enhanced Logging**: Separate auth and security log formats
- **Security Event Tracking**: Dedicated logging for security events
- **Health Endpoints**: Built-in health check endpoints

## 📖 Examples

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
    
    -- Configure for admin area
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

## 🧪 Testing

The module includes comprehensive testing options:

### Docker Testing (Recommended)
```bash
cd test
docker-compose up --build
curl -u alice:password123 http://localhost:8080/protected/
```

### Native Linux Testing
```bash
cd test
chmod +x setup_linux.sh
./setup_linux.sh
start_test_server
test_digest_auth
```

### Production Readiness Testing
```bash
cd test
docker-compose up --build -d
docker cp test_production_ready.sh lua-resty-digest-auth-test:/tmp/
docker exec lua-resty-digest-auth-test bash -c 'chmod +x /tmp/test_production_ready.sh && /tmp/test_production_ready.sh'
```

## 📊 Performance

The module is optimized for high-performance environments:

- **Concurrent Requests**: Handles 50+ simultaneous authentication requests
- **Memory Efficiency**: Minimal memory footprint with shared memory usage
- **Response Time**: Sub-millisecond authentication response times
- **Scalability**: Designed for high-traffic environments

## 🔧 User Credentials File

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

## 🚨 Troubleshooting

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

## 📈 Monitoring

### Health Checks
```bash
# Check module status
curl -f http://your-domain.com/health

# Check authentication
curl -u username:password http://your-domain.com/protected/
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

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenResty community for the excellent platform
- RFC 2617 for the HTTP Digest Authentication specification
- Contributors and testers who helped improve this module

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/ElCruncharino/lua-resty-digest-auth/issues)
- **Documentation**: [Production Deployment Guide](PRODUCTION_DEPLOYMENT.md)
- **Testing**: [Test Documentation](test/README.md)

---

**Ready for production deployment with comprehensive security features!** 🚀 

## 🔒 Security Hardening

This module includes additional security mitigations beyond standard Digest Auth:
- Header name and value sanitization and length checks
- Shared memory key sanitization
- Log value sanitization
- Credential file path validation (absolute, no traversal, whitelisted dirs)
- Constant-time string comparison for authentication
- Utility for periodic nonce cleanup

These mitigations further reduce the risk of memory exhaustion, log injection, timing attacks, and key collisions. 

- homepage: https://github.com/ElCruncharino/lua-resty-digest-auth
- repository: https://github.com/ElCruncharino/lua-resty-digest-auth.git
- issues: https://github.com/ElCruncharino/lua-resty-digest-auth/issues
- maintainer: ElCruncharino 