FROM openresty/openresty:alpine-slim

# Install dependencies
RUN apk add --no-cache \
    curl \
    bash

# Create necessary directories
RUN mkdir -p /usr/local/openresty/nginx/logs \
    && mkdir -p /usr/local/openresty/nginx/html \
    && mkdir -p /usr/local/openresty/lualib/resty \
    && mkdir -p /etc/nginx

# Copy the module
COPY lib/resty/digest_auth.lua /usr/local/openresty/lualib/resty/

# Create test credentials (HA1 = MD5(username:realm:password))
# alice:password123, bob:password456, admin:adminpass
RUN echo "alice:Test Realm:49e8d18599d46ed533eb6f4ca0325170" > /etc/nginx/htdigest \
    && echo "bob:Test Realm:357db14c909f66b39af570a770703768" >> /etc/nginx/htdigest \
    && echo "admin:Test Realm:812262381af0c3906de59b610343dfdf" >> /etc/nginx/htdigest \
    && chmod 644 /etc/nginx/htdigest

# Create nginx configuration
COPY test/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Copy all test scripts
COPY test/basic_auth_test.sh /usr/local/bin/basic_auth_test
COPY test/advanced_test.sh /usr/local/bin/advanced_test
COPY test/memory_management_test.sh /usr/local/bin/memory_management_test
COPY test/brute_force_test.sh /usr/local/bin/brute_force_test
COPY test/exhaustive_auth_test.sh /usr/local/bin/exhaustive_auth_test
COPY test/production_test.sh /usr/local/bin/production_test
RUN chmod +x /usr/local/bin/*_test /usr/local/bin/*_auth_test /usr/local/bin/production_test

# Create start script
COPY test/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["/usr/local/bin/start.sh"] 