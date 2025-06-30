#!/bin/bash

# lua-resty-digest-auth Test Setup Script
# This script sets up a complete testing environment for the digest auth module

set -e

echo "🚀 Setting up lua-resty-digest-auth test environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Update package list
print_status "Updating package list..."
sudo apt update

# Install dependencies
print_status "Installing dependencies..."
sudo apt install -y wget curl build-essential libpcre3-dev libssl-dev zlib1g-dev

# Install OpenResty
print_status "Installing OpenResty..."
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    # Remove any existing OpenResty repository
    sudo rm -f /etc/apt/sources.list.d/openresty.list
    sudo rm -f /usr/share/keyrings/openresty-archive-keyring.gpg
    
    # Add OpenResty GPG key using apt-key (fallback method)
    wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
    
    # Add repository
    echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
    
    # Update and install
    sudo apt update
    sudo apt install -y openresty
else
    # Old method for OpenResty
    wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
    echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
    sudo apt update
    sudo apt install -y openresty
fi

# Create test directory structure
print_status "Creating test directory structure..."
sudo mkdir -p /usr/local/openresty/nginx/conf.d
sudo mkdir -p /usr/local/openresty/nginx/logs
sudo mkdir -p /usr/local/openresty/nginx/html
sudo mkdir -p /etc/nginx/ssl

# Set proper permissions
sudo chown -R $USER:$USER /usr/local/openresty/nginx/html
sudo chown -R $USER:$USER /usr/local/openresty/nginx/logs

# Install the module
print_status "Installing lua-resty-digest-auth module..."
sudo mkdir -p /usr/local/openresty/lualib/resty
sudo cp ../lib/resty/digest_auth.lua /usr/local/openresty/lualib/resty/

# Create test credentials
print_status "Creating test credentials..."
cat > /tmp/htdigest << 'EOF'
# Test users for lua-resty-digest-auth
# Format: username:realm:HA1_hash
# 
# Test users:
# - alice with password "password123" in realm "Test Realm"
# - bob with password "secret456" in realm "Test Realm"
# - admin with password "adminpass" in realm "Admin Area"

alice:Test Realm:5f4dcc3b5aa765d61d8327deb882cf99
bob:Test Realm:7c4a8d09ca3762af61e59520943dc26494f8941b
admin:Admin Area:21232f297a57a5a743894a0e4a801fc3
EOF

sudo cp /tmp/htdigest /etc/nginx/htdigest
sudo chmod 644 /etc/nginx/htdigest

# Create test nginx configuration
print_status "Creating test nginx configuration..."
cat > /tmp/nginx.conf << 'EOF'
# Test configuration for lua-resty-digest-auth
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /usr/local/openresty/nginx/conf/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /usr/local/openresty/nginx/logs/access.log main;
    error_log /usr/local/openresty/nginx/logs/error.log;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Shared memory for digest auth
    lua_shared_dict digest_auth 2m;
    lua_shared_dict digest_auth_ratelimit 1m;

    # Initialize digest auth module
    init_by_lua_block {
        local DigestAuth = require "resty.digest_auth"
        
        local ok, err = DigestAuth.configure {
            shared_memory_name = "digest_auth",
            credentials_file = "/etc/nginx/htdigest",
            realm = "Test Realm",
            nonce_lifetime = 300,        -- 5 minutes for testing
            max_nonce_uses = 100,        -- 100 reuses for testing
            rate_limit = {
                enabled = true,
                max_attempts = 10,
                window_seconds = 300,
                block_seconds = 60
            }
        }
        
        if not ok then
            error("Failed to configure digest auth: " .. (err or "unknown error"))
        end
        
        ngx.log(ngx.INFO, "DigestAuth module configured successfully")
    }

    server {
        listen 8080;
        server_name localhost;
        
        # Public content
        location / {
            return 200 "Public content - no authentication required\n";
            add_header Content-Type text/plain;
        }
        
        # Protected content
        location /protected/ {
            access_by_lua_block {
                ngx.log(ngx.ERR, "DigestAuth access_by_lua_block executed")
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.require_auth()
            }
            
            return 200 "Protected content - authentication successful!\n";
            add_header Content-Type text/plain;
        }
        
        # API endpoint
        location /api/ {
            access_by_lua_block {
                ngx.log(ngx.ERR, "DigestAuth access_by_lua_block executed")
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.require_auth()
            }
            
            return 200 '{"status": "authenticated", "message": "API access granted"}\n';
            add_header Content-Type application/json;
        }
        
        # Admin area
        location /admin/ {
            access_by_lua_block {
                ngx.log(ngx.ERR, "DigestAuth access_by_lua_block executed")
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.require_auth()
            }
            
            return 200 "Admin area - restricted access\n";
            add_header Content-Type text/plain;
        }
        
        # Health check
        location /health {
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
        
        # Utility endpoints for testing
        location /test/clear-memory {
            access_by_lua_block {
                ngx.log(ngx.ERR, "DigestAuth access_by_lua_block executed")
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.require_auth()
            }
            
            content_by_lua_block {
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.clear_memory()
                ngx.say("Memory cleared successfully")
            }
        }
        
        location /test/clear-nonces {
            access_by_lua_block {
                ngx.log(ngx.ERR, "DigestAuth access_by_lua_block executed")
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.require_auth()
            }
            
            content_by_lua_block {
                local DigestAuth = require "resty.digest_auth"
                DigestAuth.clear_nonces()
                ngx.say("Nonces cleared successfully")
            }
        }
    }
}
EOF

sudo cp /tmp/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Create test script
print_status "Creating test script..."
cat > /tmp/test_digest_auth.sh << 'EOF'
#!/bin/bash

# Test script for lua-resty-digest-auth
BASE_URL="http://localhost:8080"

echo "🧪 Testing lua-resty-digest-auth module..."
echo "=========================================="

# Test public endpoint
echo -e "\n1. Testing public endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/"

# Test protected endpoint (should get 401)
echo -e "\n2. Testing protected endpoint (expecting 401)..."
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# Test with valid credentials
echo -e "\n3. Testing with valid credentials (alice:password123)..."
curl -s -u "alice:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# Test with invalid credentials
echo -e "\n4. Testing with invalid credentials..."
curl -s -u "alice:wrongpassword" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# Test API endpoint
echo -e "\n5. Testing API endpoint with valid credentials..."
curl -s -u "bob:secret456" -w "Status: %{http_code}\n" "$BASE_URL/api/"

# Test admin endpoint
echo -e "\n6. Testing admin endpoint with valid credentials..."
curl -s -u "admin:adminpass" -w "Status: %{http_code}\n" "$BASE_URL/admin/"

# Test health endpoint
echo -e "\n7. Testing health endpoint..."
curl -s -w "Status: %{http_code}\n" "$BASE_URL/health"

echo -e "\n✅ Testing complete!"
echo -e "\nTo test manually:"
echo "  curl -u alice:password123 http://localhost:8080/protected/"
echo "  curl -u bob:secret456 http://localhost:8080/api/"
echo "  curl -u admin:adminpass http://localhost:8080/admin/"
EOF

chmod +x /tmp/test_digest_auth.sh
sudo mv /tmp/test_digest_auth.sh /usr/local/bin/test_digest_auth

# Create start/stop scripts
print_status "Creating service management scripts..."

cat > /tmp/start_test_server.sh << 'EOF'
#!/bin/bash
echo "Starting OpenResty test server..."
sudo /usr/local/openresty/bin/openresty -p /usr/local/openresty/nginx -c /usr/local/openresty/nginx/conf/nginx.conf
echo "Server started on http://localhost:8080"
EOF

cat > /tmp/stop_test_server.sh << 'EOF'
#!/bin/bash
echo "Stopping OpenResty test server..."
sudo /usr/local/openresty/bin/openresty -p /usr/local/openresty/nginx -c /usr/local/openresty/nginx/conf/nginx.conf -s stop
echo "Server stopped"
EOF

cat > /tmp/restart_test_server.sh << 'EOF'
#!/bin/bash
echo "Restarting OpenResty test server..."
sudo /usr/local/openresty/bin/openresty -p /usr/local/openresty/nginx -c /usr/local/openresty/nginx/conf/nginx.conf -s reload
echo "Server restarted"
EOF

chmod +x /tmp/start_test_server.sh /tmp/stop_test_server.sh /tmp/restart_test_server.sh
sudo mv /tmp/start_test_server.sh /usr/local/bin/start_test_server
sudo mv /tmp/stop_test_server.sh /usr/local/bin/stop_test_server
sudo mv /tmp/restart_test_server.sh /usr/local/bin/restart_test_server

print_success "Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Start the test server: start_test_server"
echo "2. Run the test script: test_digest_auth"
echo "3. Test manually with curl:"
echo "   curl -u alice:password123 http://localhost:8080/protected/"
echo ""
echo "🔧 Management commands:"
echo "  start_test_server  - Start the test server"
echo "  stop_test_server   - Stop the test server"
echo "  restart_test_server - Restart the test server"
echo "  test_digest_auth   - Run automated tests"
echo ""
echo "📁 Files created:"
echo "  /etc/nginx/htdigest - Test credentials"
echo "  /usr/local/openresty/nginx/conf/nginx.conf - Test configuration"
echo "  /usr/local/openresty/lualib/resty/digest_auth.lua - Module installed"
echo ""
echo "🌐 Test URLs:"
echo "  http://localhost:8080/ - Public content"
echo "  http://localhost:8080/protected/ - Protected content"
echo "  http://localhost:8080/api/ - API endpoint"
echo "  http://localhost:8080/admin/ - Admin area"
echo "  http://localhost:8080/health - Health check" 