#!/bin/bash

# Start script for lua-resty-digest-auth test container

echo "🚀 Starting lua-resty-digest-auth test server..."

# Start OpenResty in foreground
exec /usr/local/openresty/bin/openresty -g "daemon off;" -p /usr/local/openresty/nginx -c /usr/local/openresty/nginx/conf/nginx.conf 