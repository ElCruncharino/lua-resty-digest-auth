# Testing lua-resty-digest-auth

This directory contains everything you need to test the digest auth module.

## 🚀 Quick Start

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

## 🧪 Running Tests

```bash
# Basic tests
test_digest_auth

# Production readiness tests
docker cp test_production_ready.sh lua-resty-digest-auth-test:/tmp/
docker exec lua-resty-digest-auth-test bash -c 'chmod +x /tmp/test_production_ready.sh && /tmp/test_production_ready.sh'

# Performance tests
docker cp performance_test.sh lua-resty-digest-auth-test:/tmp/
docker exec lua-resty-digest-auth-test bash -c 'chmod +x /tmp/performance_test.sh && /tmp/performance_test.sh'
```

## 🔧 Management Commands

```bash
start_test_server  - Start the test server
stop_test_server   - Stop the test server
restart_test_server - Restart the test server
test_digest_auth   - Run automated tests
```

## 🔍 Troubleshooting

### Server won't start
```bash
# Check if port 8080 is in use
sudo netstat -tlnp | grep :8080

# Check logs
tail -f /usr/local/openresty/nginx/logs/error.log
```

### Authentication not working
```bash
# Check if credentials file exists
ls -la /etc/nginx/htdigest

# Check if module is installed
ls -la /usr/local/openresty/lualib/resty/digest_auth.lua
```

For more detailed testing information, see the main [README.md](../README.md). 