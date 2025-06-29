# Docker Testing Guide for lua-resty-digest-auth

This guide shows you how to test the digest auth module using Docker containers, which provides a consistent testing environment across all platforms.

## 🐳 Quick Start with Docker

### Option 1: Docker Compose (Recommended)

```bash
# Navigate to the test directory
cd test

# Build and start the test environment
docker-compose up --build

# In another terminal, test the endpoints
curl -u alice:password123 http://localhost:8080/protected/
curl -u bob:secret456 http://localhost:8080/api/
curl -u admin:adminpass http://localhost:8080/admin/
```

### Option 2: Manual Docker Build

```bash
# Navigate to the test directory
cd test

# Build the test image
docker build -t lua-resty-digest-auth-test -f Dockerfile ..

# Run the container
docker run -d --name digest-auth-test -p 8080:8080 lua-resty-digest-auth-test

# Test the endpoints
curl -u alice:password123 http://localhost:8080/protected/

# Stop and remove the container
docker stop digest-auth-test
docker rm digest-auth-test
```

### Option 3: Interactive Testing

```bash
# Run the container interactively
docker run -it --rm -p 8080:8080 lua-resty-digest-auth-test bash

# Inside the container, run tests
test_digest_auth

# Or test manually
curl -u alice:password123 http://localhost:8080/protected/
```

## 🧪 Running Tests

### Automated Test Suite

```bash
# Run the full test suite
docker exec digest-auth-test test_digest_auth
```

### Manual Testing

```bash
# Test public endpoint
curl http://localhost:8080/

# Test protected endpoint (should get 401)
curl http://localhost:8080/protected/

# Test with valid credentials
curl -u alice:password123 http://localhost:8080/protected/
curl -u bob:secret456 http://localhost:8080/api/
curl -u admin:adminpass http://localhost:8080/admin/

# Test with invalid credentials
curl -u alice:wrongpassword http://localhost:8080/protected/

# Test health endpoint
curl http://localhost:8080/health
```

### Browser Testing

1. Open your browser and navigate to `http://localhost:8080/protected/`
2. Enter credentials when prompted:
   - Username: `alice`
   - Password: `password123`

## 🔧 Docker Commands

### Basic Operations

```bash
# Start the test environment
docker-compose up -d

# View logs
docker-compose logs -f digest-auth-test

# Stop the environment
docker-compose down

# Rebuild and restart
docker-compose up --build -d

# Check container status
docker-compose ps
```

### Debugging

```bash
# Access container shell
docker exec -it digest-auth-test bash

# View nginx logs
docker exec digest-auth-test tail -f /usr/local/openresty/nginx/logs/error.log
docker exec digest-auth-test tail -f /usr/local/openresty/nginx/logs/access.log

# Check nginx configuration
docker exec digest-auth-test /usr/local/openresty/bin/openresty -t

# Test module loading
docker exec digest-auth-test lua -e 'require "resty.digest_auth"'
```

### Performance Testing

```bash
# Load testing with multiple containers
for i in {1..5}; do
  docker run --rm --network host curlimages/curl:latest \
    -u alice:password123 http://localhost:8080/protected/ &
done
wait

# Rate limit testing
for i in {1..15}; do
  curl -u alice:wrongpassword http://localhost:8080/protected/
done
```

## 🌐 Multi-Platform Testing

### Test on Different Linux Distributions

```bash
# Ubuntu 20.04 (default)
docker build -t digest-auth-ubuntu20 -f Dockerfile ..

# Ubuntu 18.04
docker build -t digest-auth-ubuntu18 -f Dockerfile.ubuntu18 ..

# CentOS 8
docker build -t digest-auth-centos8 -f Dockerfile.centos8 ..

# Alpine Linux
docker build -t digest-auth-alpine -f Dockerfile.alpine ..
```

### Cross-Architecture Testing

```bash
# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t digest-auth-multiarch -f Dockerfile ..

# Test on ARM64 (Apple Silicon, Raspberry Pi)
docker run --platform linux/arm64 -p 8080:8080 digest-auth-multiarch
```

## 📊 CI/CD Integration

### GitHub Actions with Docker

```yaml
name: Docker Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and test
        run: |
          cd test
          docker-compose up --build -d
          sleep 10
          curl -u alice:password123 http://localhost:8080/protected/
          docker-compose down
```

### Local CI Testing

```bash
# Run tests in CI mode
docker-compose -f docker-compose.ci.yml up --build --abort-on-container-exit
```

## 🔍 Advanced Testing Scenarios

### Custom Credentials

```bash
# Create custom credentials file
cat > custom_htdigest << 'EOF'
user1:Test Realm:5f4dcc3b5aa765d61d8327deb882cf99
user2:Test Realm:7c4a8d09ca3762af61e59520943dc26494f8941b
EOF

# Run with custom credentials
docker run -d --name digest-auth-custom \
  -p 8081:8080 \
  -v $(pwd)/custom_htdigest:/etc/nginx/htdigest \
  lua-resty-digest-auth-test
```

### Custom Configuration

```bash
# Create custom nginx config
cat > custom_nginx.conf << 'EOF'
# Custom configuration here
EOF

# Run with custom config
docker run -d --name digest-auth-custom \
  -p 8081:8080 \
  -v $(pwd)/custom_nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
  lua-resty-digest-auth-test
```

### Network Testing

```bash
# Create custom network
docker network create digest-auth-network

# Run with custom network
docker run -d --name digest-auth-test \
  --network digest-auth-network \
  -p 8080:8080 \
  lua-resty-digest-auth-test

# Test from another container
docker run --rm --network digest-auth-network \
  curlimages/curl:latest \
  -u alice:password123 http://digest-auth-test:8080/protected/
```

## 🧹 Cleanup

### Remove Test Environment

```bash
# Stop and remove containers
docker-compose down

# Remove images
docker rmi lua-resty-digest-auth-test

# Remove volumes (if any)
docker volume prune

# Remove networks
docker network prune
```

### Complete Cleanup

```bash
# Remove all related containers, images, and networks
docker-compose down --rmi all --volumes --remove-orphans
docker system prune -f
```

## 📝 Troubleshooting

### Common Issues

**Container won't start:**
```bash
# Check logs
docker-compose logs digest-auth-test

# Check if port is in use
netstat -tlnp | grep :8080

# Try different port
docker-compose up -p 8081:8080
```

**Module not found:**
```bash
# Check if module is installed
docker exec digest-auth-test ls -la /usr/local/openresty/lualib/resty/digest_auth.lua

# Check module syntax
docker exec digest-auth-test lua -l resty.digest_auth
```

**Authentication not working:**
```bash
# Check credentials file
docker exec digest-auth-test cat /etc/nginx/htdigest

# Check nginx configuration
docker exec digest-auth-test /usr/local/openresty/bin/openresty -t
```

### Performance Issues

```bash
# Monitor container resources
docker stats digest-auth-test

# Check memory usage
docker exec digest-auth-test free -h

# Check disk usage
docker exec digest-auth-test df -h
```

## 🎯 Expected Results

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

## 🚀 Production Considerations

### Security

```bash
# Run as non-root user
docker run -u 1000:1000 -p 8080:8080 lua-resty-digest-auth-test

# Use read-only filesystem
docker run --read-only -p 8080:8080 lua-resty-digest-auth-test

# Limit container capabilities
docker run --cap-drop=ALL -p 8080:8080 lua-resty-digest-auth-test
```

### Monitoring

```bash
# Enable health checks
docker run --health-cmd="curl -f http://localhost:8080/health" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  -p 8080:8080 lua-resty-digest-auth-test

# Monitor logs
docker logs -f digest-auth-test
```

### Scaling

```bash
# Run multiple instances
docker-compose up --scale digest-auth-test=3

# Load balancing with nginx
docker run -d --name nginx-lb \
  -p 80:80 \
  -v $(pwd)/nginx-lb.conf:/etc/nginx/nginx.conf \
  nginx:alpine
``` 