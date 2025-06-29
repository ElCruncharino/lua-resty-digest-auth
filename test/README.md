# Testing lua-resty-digest-auth

This directory contains everything you need to test the digest auth module locally on multiple platforms.

## 🚀 Quick Start Options

### Option 1: Native Linux (Recommended)

```bash
# Navigate to the test directory
cd test

# Run the native Linux setup script
chmod +x setup_linux.sh
./setup_linux.sh
```

**Supported Distributions:**
- Ubuntu 18.04, 20.04, 22.04
- Debian 9, 10, 11
- CentOS 7, 8
- Red Hat Enterprise Linux 7, 8
- Fedora 30+

### Option 2: WSL (Windows Subsystem for Linux)

```bash
# Navigate to the test directory
cd test

# Run the WSL setup script
chmod +x setup.sh
./setup.sh
```

### Option 3: Windows Testing

```cmd
# Run the Windows test script (requires WSL)
test_windows.bat
```

## 🧪 Running Tests

### Start the Test Server

```bash
# Start the OpenResty test server
start_test_server

# Or use systemd service (Linux only)
sudo systemctl start digest-auth-test
```

### Run Automated Tests

```bash
# Run comprehensive test suite
test_digest_auth

# Or test manually
curl -u alice:password123 http://localhost:8080/protected/
curl -u bob:secret456 http://localhost:8080/api/
curl -u admin:adminpass http://localhost:8080/admin/
```

## 📋 Test Credentials

| Username | Password | Realm | Purpose |
|----------|----------|-------|---------|
| alice | password123 | Test Realm | General testing |
| bob | secret456 | Test Realm | API testing |
| admin | adminpass | Admin Area | Admin testing |

## 🌐 Test Endpoints

| URL | Description | Auth Required |
|-----|-------------|---------------|
| `http://localhost:8080/` | Public content | No |
| `http://localhost:8080/protected/` | Protected content | Yes |
| `http://localhost:8080/api/` | API endpoint | Yes |
| `http://localhost:8080/admin/` | Admin area | Yes |
| `http://localhost:8080/health` | Health check | No |
| `http://localhost:8080/test/clear-memory` | Clear shared memory | Yes |
| `http://localhost:8080/test/clear-nonces` | Clear nonces | Yes |

## 🔧 Management Commands

### Basic Commands
```bash
start_test_server  - Start the test server
stop_test_server   - Stop the test server
restart_test_server - Restart the test server
test_digest_auth   - Run automated tests
```

### Systemd Commands (Linux only)
```bash
sudo systemctl start digest-auth-test    # Start service
sudo systemctl stop digest-auth-test     # Stop service
sudo systemctl restart digest-auth-test  # Restart service
sudo systemctl enable digest-auth-test   # Enable on boot
sudo systemctl status digest-auth-test   # Check status
```

### Logging
```bash
# View logs
tail -f /usr/local/openresty/nginx/logs/error.log
tail -f /usr/local/openresty/nginx/logs/access.log

# Check systemd logs (if using systemd)
sudo journalctl -u digest-auth-test -f
```

## ⚙️ Configuration

The test environment uses these settings:

- **Port**: 8080
- **Realm**: "Test Realm"
- **Nonce Lifetime**: 5 minutes (for testing)
- **Max Nonce Uses**: 100 (for testing)
- **Rate Limiting**: Enabled (10 attempts per 5 minutes)

## 🧪 CI/CD Testing

The project includes GitHub Actions workflows that test on:

- Ubuntu 18.04, 20.04, 22.04
- CentOS 8
- Multiple OpenResty versions

To run CI tests locally:

```bash
# Test on Ubuntu
docker run --rm -v $(pwd):/app -w /app ubuntu:20.04 bash -c "
  apt update && apt install -y curl
  cd test && chmod +x setup_linux.sh && ./setup_linux.sh
  start_test_server
  test_digest_auth
"

# Test on CentOS
docker run --rm -v $(pwd):/app -w /app centos:8 bash -c "
  yum update -y && yum install -y curl
  cd test && chmod +x setup_linux.sh && ./setup_linux.sh
  start_test_server
  test_digest_auth
"
```

## 🔍 Troubleshooting

### Server won't start

```bash
# Check if port 8080 is in use
sudo netstat -tlnp | grep :8080

# Check nginx configuration
sudo /usr/local/openresty/bin/openresty -t -p /usr/local/openresty/nginx -c /usr/local/openresty/nginx/conf/nginx.conf

# Check logs
tail -f /usr/local/openresty/nginx/logs/error.log
```

### Authentication not working

```bash
# Check if credentials file exists
ls -la /etc/nginx/htdigest

# Check if module is installed
ls -la /usr/local/openresty/lualib/resty/digest_auth.lua

# Test module loading
lua -e 'require "resty.digest_auth"'
```

### Rate limiting issues

```bash
# Clear rate limit memory
curl -u alice:password123 http://localhost:8080/test/clear-memory

# Check rate limit status in logs
grep "rate limit" /usr/local/openresty/nginx/logs/error.log
```

### Distribution-specific issues

**Ubuntu/Debian:**
```bash
# If apt-key is deprecated
wget -qO - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/openresty-archive-keyring.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
```

**CentOS/RHEL:**
```bash
# If yum-config-manager not found
sudo yum install -y yum-utils
```

## 🌐 Browser Testing

You can also test in a web browser:

1. Open `http://localhost:8080/protected/`
2. Enter credentials when prompted:
   - Username: `alice`
   - Password: `password123`

## 📊 Performance Testing

```bash
# Test with multiple concurrent requests
for i in {1..10}; do
  curl -u alice:password123 http://localhost:8080/protected/ &
done
wait

# Test rate limiting
for i in {1..15}; do
  curl -u alice:wrongpassword http://localhost:8080/protected/
done

# Load testing with Apache Bench
ab -n 100 -c 10 -A alice:password123 http://localhost:8080/protected/
```

## 🧹 Cleanup

### Remove test environment

```bash
# Stop the server
stop_test_server

# Remove test files
sudo rm -f /etc/nginx/htdigest
sudo rm -f /usr/local/openresty/lualib/resty/digest_auth.lua
sudo rm -f /usr/local/bin/start_test_server
sudo rm -f /usr/local/bin/stop_test_server
sudo rm -f /usr/local/bin/restart_test_server
sudo rm -f /usr/local/bin/test_digest_auth

# Remove systemd service (if created)
sudo systemctl stop digest-auth-test
sudo systemctl disable digest-auth-test
sudo rm -f /etc/systemd/system/digest-auth-test.service
sudo systemctl daemon-reload
```

### Complete uninstall

```bash
# Remove OpenResty (optional)
sudo apt remove openresty  # Ubuntu/Debian
sudo yum remove openresty  # CentOS/RHEL
```

## 📝 Platform Notes

### Native Linux
- ✅ Full systemd integration
- ✅ Automatic dependency detection
- ✅ Support for multiple distributions
- ✅ Production-like environment

### WSL
- ✅ Easy setup on Windows
- ✅ Full Linux compatibility
- ✅ Good for development
- ⚠️ Performance overhead

### Windows
- ✅ Easy testing from Windows
- ⚠️ Requires WSL
- ⚠️ Limited to HTTP testing

## 🎯 Expected Test Results

```bash
# Public endpoint
curl http://localhost:8080/          # 200 OK

# Protected endpoint without auth
curl http://localhost:8080/protected/ # 401 Unauthorized

# Protected endpoint with valid auth
curl -u alice:password123 http://localhost:8080/protected/ # 200 OK

# Protected endpoint with invalid auth
curl -u alice:wrongpassword http://localhost:8080/protected/ # 401 Unauthorized

# Rate limited (after multiple failed attempts)
curl -u alice:wrongpassword http://localhost:8080/protected/ # 403 Forbidden
``` 