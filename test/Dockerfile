FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENRESTY_VERSION=1.21.4.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install OpenResty
RUN wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add - \
    && echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list \
    && apt-get update \
    && apt-get install -y openresty \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /usr/local/openresty/nginx/logs \
    && mkdir -p /usr/local/openresty/nginx/html \
    && mkdir -p /usr/local/openresty/lualib/resty \
    && mkdir -p /etc/nginx

# Copy the module
COPY lib/resty/digest_auth.lua /usr/local/openresty/lualib/resty/

# Create test credentials
RUN echo "alice:Test Realm:5f4dcc3b5aa765d61d8327deb882cf99" > /etc/nginx/htdigest \
    && echo "bob:Test Realm:7c4a8d09ca3762af61e59520943dc26494f8941b" >> /etc/nginx/htdigest \
    && echo "admin:Admin Area:21232f297a57a5a743894a0e4a801fc3" >> /etc/nginx/htdigest \
    && chmod 644 /etc/nginx/htdigest

# Create nginx configuration
COPY test/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Create test script
COPY test/test_digest_auth.sh /usr/local/bin/test_digest_auth
RUN chmod +x /usr/local/bin/test_digest_auth

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