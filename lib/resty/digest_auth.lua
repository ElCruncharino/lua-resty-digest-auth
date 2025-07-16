--[[
    lua-resty-digest-auth
    A modern, plug-and-play OpenResty module for HTTP Digest Authentication
    
    Copyright (c) 2025
    License: MIT
    
    Inspired by the concept of HTTP Digest Authentication but completely
    redesigned for modern OpenResty usage patterns.
]]

local tab_concat = table.concat

-- External dependencies
local random = require "resty.random"
local cjson = require "cjson"
local bit = require "bit"

-- Logging utilities
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local ngx_INFO = ngx.INFO
local ngx_DEBUG = ngx.DEBUG

-- Module state
local DigestAuth = {
    _VERSION = '1.0.3',
    _AUTHOR = 'ElCruncharino',
    _LICENSE = 'MIT'
}

-- Default configuration
local DEFAULT_CONFIG = {
    realm = "Protected Area",
    nonce_lifetime = 600,      -- 10 minutes
    max_nonce_uses = 500,      -- 500 reuses per nonce
    refresh_threshold = 80,    -- Refresh at 80% usage
    algorithm = "MD5-sess",    -- MD5-sess or SHA-256-sess per RFC 7616
    algorithm = "MD5-sess",    -- MD5-sess or SHA-256-sess per RFC 7616
    rate_limit = {
        enabled = false,
        max_attempts = 50,
        window_seconds = 600,
        block_seconds = 300
    },
    brute_force = {
        enabled = true,
        max_failed_attempts = 10,
        window_seconds = 300,  -- 5 minutes
        block_seconds = 1800,  -- 30 minutes
        suspicious_patterns = {
            common_passwords = {"password", "123456", "admin", "root", "test", "guest", "user"},
            empty_credentials = true,
            malformed_headers = true,
            rapid_requests = 5,  -- requests per second threshold
            username_enumeration = 3  -- failed attempts per username threshold
        }
    }
}

-- Internal state
local config = {}
local user_credentials = {}
local shared_memory = nil
local rate_limit_memory = nil
local server_salt = nil

-- Utility functions
local function sanitize_header_name(name)
    return tostring(name):gsub("[^%w%-]", "")
end

local function sanitize_key(key)
    return tostring(key):gsub("[^%w%-%.]", "_")
end

local function sanitize_log_value(value)
    return tostring(value):gsub("[%z\1-\31]", "?")
end

local function constant_time_compare(a, b)
    if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
        return false
    end
    local result = 0
    for i = 1, #a do
        result = bit.bxor(result, bit.bxor(a:byte(i), b:byte(i)))
    end
    return result == 0
end

local function validate_and_merge_config(options)
    -- Merge with defaults
    for key, value in pairs(DEFAULT_CONFIG) do
        if options[key] == nil then
            options[key] = value
        end
    end
    
    config = options
    
    -- Validate required options
    if not config.shared_memory_name then
        return false, "shared_memory_name is required"
    end
    
    if not config.credentials_file then
        return false, "credentials_file is required"
    end
    
    local valid_path, path_err = validate_file_path(config.credentials_file)
    if not valid_path then
        return false, "Invalid credentials_file: " .. (path_err or "")
    end
    
    return true
end

local function initialize_shared_memory()
    -- Initialize shared memory
    shared_memory = ngx.shared[config.shared_memory_name]
    if not shared_memory then
        return false, "Shared memory '" .. config.shared_memory_name .. "' not found"
    end
    
    -- Initialize rate limiting if enabled
    if config.rate_limit.enabled then
        local rate_limit_shm_name = config.rate_limit.shared_memory_name or "digest_auth_ratelimit"
        rate_limit_memory = ngx.shared[rate_limit_shm_name]
        if not rate_limit_memory then
            ngx_log(ngx_WARN, "Rate limit shared memory '" .. rate_limit_shm_name .. "' not found, disabling rate limiting")
            config.rate_limit.enabled = false
        end
    end
    
    return true
end

local function validate_file_path(path)
    if not path:match("^/") then
        return false, "Path must be absolute"
    end
    if path:match("%.%.") then
        return false, "Path traversal not allowed"
    end
    local allowed_dirs = {"/etc/nginx/", "/usr/local/openresty/nginx/"}
    local allowed = false
    for _, dir in ipairs(allowed_dirs) do
        if path:sub(1, #dir) == dir then
            allowed = true
            break
        end
    end
    if not allowed then
        return false, "Path not in allowed directory"
    end
    return true
end

local function extract_header_value(header, name, quoted)
    name = sanitize_header_name(name)
    if #header > 4096 then return nil end
    local pattern = quoted and '"([^"]+)"' or '([^,]+)'
    local _, _, value = header:find("[, ]" .. name .. "=" .. pattern)
    if value and #value > 1024 then return nil end
    return value and value:gsub("^%s*(.-)%s*$", "%1")
end

local function validate_utf8_field(field_name, value)
    local function validate_utf8(str)
        return pcall(function() require("utf8").len(str) end)
    end

    if not validate_utf8(value) then
        ngx_log(ngx_WARN, "Invalid UTF-8 in ", field_name)
        return false
    end
    return true
end

local function validate_uri_match(auth_data)
    if not auth_data.uri or auth_data.uri ~= ngx.var.request_uri then
        ngx_log(ngx_WARN, "URI mismatch: ", auth_data.uri or "nil", " vs ", ngx.var.request_uri)
        return false
    end
    return true
end

local function validate_required_auth_fields(auth_data)
    if not auth_data.username or not auth_data.response or not auth_data.uri or
        not auth_data.nonce or not auth_data.realm
    then
        ngx_log(ngx_WARN, "Missing required authentication fields.")
        return false
    end
    return true
end

local function validate_qop_fields(auth_data)
    if auth_data.qop and (auth_data.qop ~= "auth" or not auth_data.cnonce or not auth_data.nc) then
        ngx_log(ngx_WARN, "Invalid qop or missing cnonce/nc for qop=auth.")
        return false
    end
    return true
end

local function parse_authorization_header(header)
    local prefix = "Digest "
    if header:sub(1, #prefix) ~= prefix then
        return nil
    end

    local auth_data = {}
    auth_data.username = extract_header_value(header, "username", true)
    auth_data.qop = extract_header_value(header, "qop", false)
    auth_data.realm = extract_header_value(header, "realm", true)
    auth_data.nonce = extract_header_value(header, "nonce", true)
    auth_data.nc = extract_header_value(header, "nc", false)
    auth_data.uri = extract_header_value(header, "uri", true)
    auth_data.cnonce = extract_header_value(header, "cnonce", true)
    auth_data.response = extract_header_value(header, "response", true)
    auth_data.opaque = extract_header_value(header, "opaque", true)

    if not validate_utf8_field("username", auth_data.username) then return nil end
    if not validate_utf8_field("realm", auth_data.realm) then return nil end
    if not validate_uri_match(auth_data) then return nil end
    if not validate_required_auth_fields(auth_data) then return nil end
    if not validate_qop_fields(auth_data) then return nil end

    return auth_data
end

local function load_credentials(file_path)
    local file, err = io.open(file_path, "r")
    if not file then
        return nil, "Failed to open credentials file: " .. err
    end
    
    local users_loaded = 0
    for line in file:lines() do
        local username, realm, ha1_hash = parse_credentials_line(line)
        if username then
            user_credentials[username] = {
                realm = realm,
                ha1_hash = ha1_hash
            }
            ngx_log(ngx_DEBUG, "Loaded user: ", username, " (realm: ", realm, ")")
            users_loaded = users_loaded + 1
        else
            ngx_log(ngx_WARN, "Invalid credentials line: ", line)
        end
    end
    
    file:close()
    
    if users_loaded == 0 then
        return nil, "No valid users found in credentials file"
    end
    return users_loaded
end

local function parse_credentials_line(line)
    if not line or line:match("^%s*#") then
        return nil, "comment or empty line"
    end

    -- Split only on the first two colons to handle realm names with spaces
    local username_end = line:find(":")
    if not username_end then
        return nil, "no first colon found"
    end
    
    local realm_end = line:find(":", username_end + 1)
    if not realm_end then
        return nil, "no second colon found"
    end
    
    local username = line:sub(1, username_end - 1):match("^%s*(.-)%s*$")
    local realm = line:sub(username_end + 1, realm_end - 1):match("^%s*(.-)%s*$")
    local ha1_hash = line:sub(realm_end + 1):match("^%s*(.-)%s*$")
    
    if not username or not realm or not ha1_hash then
        return nil, "missing required fields"
    end
    
    return username, realm, ha1_hash
end

local function get_and_increment_global_counter()
    local counter = shared_memory:get("global_counter")
    if not counter then
        local initial_bytes = random.bytes(8)
        if not initial_bytes then
            ngx_log(ngx_ERR, "Failed to generate initial counter value")
            return nil, "failed to generate initial counter"
        end
        counter = 0
        for i = 1, #initial_bytes do
            counter = counter * 256 + initial_bytes:byte(i)
        end
        counter = (counter % 10000000) + 1
        shared_memory:set("global_counter", counter)
    end

    local new_counter, err = shared_memory:incr("global_counter", 1)
    if not new_counter then
        ngx_log(ngx_ERR, "Failed to increment global counter: ", err)
        return nil, err
    end
    return new_counter
end

local function generate_nonce()
    local random_data = random.bytes(64)
    if not random_data then
        ngx_log(ngx_ERR, "Failed to generate random data for nonce")
        return nil, "failed to generate random data"
    end

    local entropy = random_data:sub(1, 32)
    local nonce_salt = random_data:sub(33, 48)
    local opaque_data = random_data:sub(49, 64)

    local new_counter, err = get_and_increment_global_counter()
    if not new_counter then
        return nil, err
    end

    local nonce_parts = {
        ngx.encode_base64(entropy),
        ":",
        tostring(new_counter),
        ":",
        tostring(ngx.time()),
        ":",
        ngx.encode_base64(nonce_salt),
        ":",
        ngx.encode_base64(server_salt),
        ":",
        ngx.encode_base64(opaque_data)
    }

    local nonce = ngx.encode_base64(table.concat(nonce_parts))

    local nonce_key = "nonce:" .. sanitize_key(nonce)
    local nonce_metadata = {
        timestamp = ngx.time(),
        counter = new_counter,
        nonce_salt = ngx.encode_base64(nonce_salt),
        opaque = ngx.encode_base64(opaque_data),
        uses = 0
    }
    
    local encoded_metadata = cjson.encode(nonce_metadata)
    local ok, err = shared_memory:set(nonce_key, encoded_metadata, config.nonce_lifetime)

    if not ok then
        ngx_log(ngx_ERR, "Failed to store nonce metadata: ", err)
        return nil, err
    end

    return nonce
end

local function validate_nonce(nonce)
    local nonce_key = "nonce:" .. sanitize_key(nonce)
    local encoded_metadata = shared_memory:get(nonce_key)
    if not encoded_metadata then
        ngx_log(ngx_WARN, "Nonce not found in shared memory: ", nonce)
        return true, nil -- Treat as stale
    end
    
    local ok, metadata = pcall(cjson.decode, encoded_metadata)
    if not ok or not metadata then
        ngx_log(ngx_WARN, "Failed to decode nonce metadata for: ", nonce)
        return true, nil
    end
    
    metadata.uses = metadata.uses + 1
    local updated_metadata = cjson.encode(metadata)
    local ok, err = shared_memory:set(nonce_key, updated_metadata, config.nonce_lifetime)
    if not ok then
        ngx_log(ngx_ERR, "Failed to update nonce usage count: ", err)
    end
    
    if metadata.uses > config.max_nonce_uses then
        ngx_log(ngx_WARN, "Nonce exceeded usage limit: ", metadata.uses, "/", config.max_nonce_uses)
        return true, metadata
    end
    
    if metadata.timestamp + config.nonce_lifetime <= ngx.time() then
        ngx_log(ngx_WARN, "Nonce expired: ", metadata.timestamp + config.nonce_lifetime, " <= ", ngx.time())
        return true, metadata
    end
    
    return false, metadata
end

local function check_rate_limit(client_ip)
    if not config.rate_limit.enabled or not rate_limit_memory then
        return true -- Rate limiting disabled
    end
    
    local attempts_key = "attempts:" .. sanitize_key(client_ip)
    local current_attempts = rate_limit_memory:get(attempts_key) or 0
    
    if current_attempts >= config.rate_limit.max_attempts then
        ngx_log(ngx_WARN, "Client rate limited: ", sanitize_log_value(client_ip), " (", current_attempts, " attempts)")
        return false
    end
    
    return true
end

local function increment_rate_limit(client_ip)
    if not config.rate_limit.enabled or not rate_limit_memory then
        return
    end
    
    local attempts_key = "attempts:" .. sanitize_key(client_ip)
    local new_attempts, err = rate_limit_memory:incr(attempts_key, 1, config.rate_limit.window_seconds)
    if not new_attempts then
        ngx_log(ngx_ERR, "Failed to increment rate limit counter: ", err)
    end
end

local function reset_rate_limit(client_ip)
    if not config.rate_limit.enabled or not rate_limit_memory then
        return
    end
    
    local attempts_key = "attempts:" .. sanitize_key(client_ip)
    local ok, err = rate_limit_memory:set(attempts_key, 0, 1)
    if not ok then
        ngx_log(ngx_ERR, "Failed to reset rate limit counter: ", err)
    end
end

-- Brute force protection functions
local function is_brute_force_blocked(client_ip)
    if not config.brute_force.enabled or not rate_limit_memory then
        return false
    end
    
    local block_key = "brute_force_block:" .. sanitize_key(client_ip)
    local blocked_until = rate_limit_memory:get(block_key)
    
    if blocked_until and blocked_until > ngx.time() then
        ngx_log(ngx_WARN, "Client blocked for brute force: ", sanitize_log_value(client_ip), " until ", sanitize_log_value(blocked_until))
        return true
    end
    
    return false
end

local function block_client_brute_force(client_ip, reason)
    if not config.brute_force.enabled or not rate_limit_memory then
        return
    end
    
    local block_key = "brute_force_block:" .. sanitize_key(client_ip)
    local block_until = ngx.time() + config.brute_force.block_seconds
    
    local ok, err = rate_limit_memory:set(block_key, block_until, config.brute_force.block_seconds)
    if not ok then
        ngx_log(ngx_ERR, "Failed to set brute force block: ", err)
        return
    end
    
    ngx_log(ngx_WARN, "Client blocked for brute force: ", sanitize_log_value(client_ip), " reason: ", sanitize_log_value(reason), " until ", sanitize_log_value(block_until))
end

local function increment_failed_attempts(client_ip, username)
    if not config.brute_force.enabled or not rate_limit_memory then
        return
    end
    
    -- Track failed attempts per client
    local failed_key = "failed_attempts:" .. sanitize_key(client_ip)
    local failed_count, err = rate_limit_memory:incr(failed_key, 1, config.brute_force.window_seconds)
    if not failed_count then
        ngx_log(ngx_ERR, "Failed to increment failed attempts counter: ", err)
        return
    end
    
    -- Track failed attempts per username (for enumeration detection)
    if username then
        local username_key = "failed_username:" .. sanitize_key(username)
        local username_failed, err = rate_limit_memory:incr(username_key, 1, config.brute_force.window_seconds)
        if not username_failed then
            ngx_log(ngx_ERR, "Failed to increment username failed attempts counter: ", err)
        end
    end
    
    -- Check if we should block
    if failed_count >= config.brute_force.max_failed_attempts then
        block_client_brute_force(client_ip, "max_failed_attempts")
    end
end

local function log_suspicious_pattern(client_ip, pattern_name)
    ngx_log(ngx_WARN, "Suspicious pattern detected: ", pattern_name, " from ", sanitize_log_value(client_ip))
end

local function check_empty_credentials(auth_data, client_ip, patterns)
    if patterns.empty_credentials and (not auth_data.username or auth_data.username == "") then
        log_suspicious_pattern(client_ip, "empty_credentials")
        return true, "empty_credentials"
    end
    return false
end

local function check_malformed_headers(auth_data, client_ip, patterns)
    if patterns.malformed_headers and not auth_data.response then
        log_suspicious_pattern(client_ip, "malformed_headers")
        return true, "malformed_headers"
    end
    return false
end

local function check_rapid_requests(client_ip, patterns)
    local rapid_key = "rapid_requests:" .. sanitize_key(client_ip)
    local rapid_count, err = rate_limit_memory:incr(rapid_key, 1, 1) -- 1 second window
    if rapid_count and rapid_count > patterns.rapid_requests then
        log_suspicious_pattern(client_ip, "rapid_requests")
        return true, "rapid_requests"
    end
    return false
end

local function detect_suspicious_pattern(auth_data, client_ip)
    if not config.brute_force.enabled then
        return false
    end
    
    local patterns = config.brute_force.suspicious_patterns
    
    local is_suspicious, pattern = check_empty_credentials(auth_data, client_ip, patterns)
    if is_suspicious then return true, pattern end
    
    is_suspicious, pattern = check_malformed_headers(auth_data, client_ip, patterns)
    if is_suspicious then return true, pattern end
    
    is_suspicious, pattern = check_rapid_requests(client_ip, patterns)
    if is_suspicious then return true, pattern end
    
    return false
end

local function check_username_enumeration(username, client_ip)
    if not config.brute_force.enabled or not rate_limit_memory then
        return false
    end
    
    local username_key = "failed_username:" .. sanitize_key(username)
    local failed_count = rate_limit_memory:get(username_key) or 0
    
    if failed_count >= config.brute_force.suspicious_patterns.username_enumeration then
        ngx_log(ngx_WARN, "Username enumeration detected for ", sanitize_log_value(username), " from ", sanitize_log_value(client_ip))
        return true
    end
    
    return false
end

local function check_user_and_realm(auth_data)
    local user_creds = user_credentials[auth_data.username]
    if not user_creds or user_creds.realm ~= auth_data.realm then
        ngx_log(ngx_WARN, "User not found or realm mismatch: ", sanitize_log_value(auth_data.username))
        return false
    end
    return true
end

local function check_opaque_match(auth_data, nonce_metadata)
    if auth_data.opaque and nonce_metadata and nonce_metadata.opaque then
        if auth_data.opaque ~= nonce_metadata.opaque then
            ngx_log(ngx_WARN, "Opaque mismatch for user: ", sanitize_log_value(auth_data.username))
            return false
        end
    end
    return true
end

local function calculate_expected_response(auth_data, ha1)
    local ha2 = ngx.md5(tab_concat({ngx.req.get_method(), auth_data.uri}, ":"))
    if auth_data.qop then
        return ngx.md5(tab_concat({ha1, auth_data.nonce, auth_data.nc, auth_data.cnonce,
                                   auth_data.qop, ha2}, ":"))
    else
        return ngx.md5(tab_concat({ha1, auth_data.nonce, ha2}, ":"))
    end
end

local function check_nonce_refresh(nonce_metadata, auth_data_username)
    if nonce_metadata and nonce_metadata.uses >= (config.max_nonce_uses * config.refresh_threshold / 100) then
        ngx_log(ngx_DEBUG, "Nonce usage near limit, refreshing for user: ", sanitize_log_value(auth_data_username))
        return true
    end
    return false
end

local function verify_credentials(auth_data)
    if not check_user_and_realm(auth_data) then
        return false, false
    end

    local stale, nonce_metadata = validate_nonce(auth_data.nonce)
    if stale then
        ngx_log(ngx_WARN, "Nonce is stale for user: ", sanitize_log_value(auth_data.username))
        return false, true
    end

    if not check_opaque_match(auth_data, nonce_metadata) then
        return false, false
    end

    local ha1 = user_credentials[auth_data.username].ha1_hash
    local expected_response = calculate_expected_response(auth_data, ha1)

    if not constant_time_compare(expected_response, auth_data.response) then
        ngx_log(ngx_WARN, "Invalid authentication attempt")
        return false, false
    end

    if check_nonce_refresh(nonce_metadata, auth_data.username) then
        return false, true
    end

    return true, false
end

local function get_opaque_from_nonce_metadata(nonce_key, nonce)
    local encoded_metadata = shared_memory:get(nonce_key)
    if encoded_metadata then
        local ok, metadata = pcall(cjson.decode, encoded_metadata)
        if ok and metadata and metadata.opaque then
            return metadata.opaque
        else
            ngx_log(ngx_WARN, "Failed to decode nonce metadata or missing opaque for: ", nonce)
        end
    end
    return nil
end

local function generate_fallback_opaque(nonce)
    local fallback_opaque_bytes = random.bytes(16)
    if fallback_opaque_bytes then
        ngx_log(ngx_WARN, "Using fallback opaque for nonce: ", nonce)
        return ngx.encode_base64(fallback_opaque_bytes)
    end
    return ""
end

local function send_challenge(stale)
    local nonce = generate_nonce()
    if not nonce then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local nonce_key = "nonce:" .. sanitize_key(nonce)
    local opaque = get_opaque_from_nonce_metadata(nonce_key, nonce) or generate_fallback_opaque(nonce)

    local challenge_header = tab_concat {
        "Digest ",
        "realm=\"", config.realm, "\"",
        ", qop=\"auth\"",
        ", algorithm=MD5",
        ", nonce=\"", nonce, "\"",
        ", opaque=\"", opaque, "\"",
        stale and ", stale=true" or ""
    }
    
    ngx.header.www_authenticate = challenge_header
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- Public API
local function setup_server_salt()
    local salt_bytes = random.bytes(16)
    if not salt_bytes then
        return nil, "Failed to generate server salt"
    end
    server_salt = ngx.encode_base64(salt_bytes)
    return true
end

local function initialize_module_components()
    local success, err = initialize_shared_memory()
    if not success then
        return nil, err
    end
    
    success, err = setup_server_salt()
    if not success then
        return nil, err
    end
    
    local users_loaded, err = load_credentials(config.credentials_file)
    if not users_loaded then
        return nil, err
    end
    
    return true, users_loaded
end

function DigestAuth.configure(options)
    local valid, err = validate_and_merge_config(options)
    if not valid then
        return nil, err
    end
    
    local success, users_loaded = initialize_module_components()
    if not success then
        return nil, users_loaded -- users_loaded contains the error message here
    end
    
    ngx_log(ngx_INFO, "DigestAuth configured successfully with ", users_loaded, " users")
    return true
end

local function handle_auth_failure(client_ip, auth_data, stale)
    increment_failed_attempts(client_ip, auth_data and auth_data.username or nil)
    return send_challenge(stale)
end

local function handle_brute_force_block(client_ip, reason)
    ngx_log(ngx_WARN, "Request blocked due to brute force protection from: ", client_ip)
    block_client_brute_force(client_ip, reason)
    return ngx.exit(ngx.HTTP_FORBIDDEN)
end

local function handle_rate_limit_exceeded(client_ip)
    ngx_log(ngx_WARN, "Rate limit exceeded for: ", client_ip)
    return send_challenge(false)
end

local function handle_suspicious_pattern(auth_data, client_ip)
    local is_suspicious, pattern = detect_suspicious_pattern(auth_data, client_ip)
    if is_suspicious then
        block_client_brute_force(client_ip, pattern)
        return true
    end
    return false
end

local function handle_username_enumeration(auth_data, client_ip)
    if check_username_enumeration(auth_data.username, client_ip) then
        block_client_brute_force(client_ip, "username_enumeration")
        return true
    end
    return false
end

function DigestAuth.require_auth(realm)
    if not config.realm then
        ngx_log(ngx_ERR, "DigestAuth not configured. Call DigestAuth.configure() first.")
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    
    local client_ip = ngx.var.remote_addr
    
    if is_brute_force_blocked(client_ip) then
        return handle_brute_force_block(client_ip, "brute_force_block")
    end
    
    if not check_rate_limit(client_ip) then
        return handle_rate_limit_exceeded(client_ip)
    end
    
    local auth_header = ngx.var.http_authorization
    if not auth_header then
        ngx_log(ngx_DEBUG, "No authorization header from: ", client_ip)
        return send_challenge(false)
    end
    
    local auth_data = parse_authorization_header(auth_header)
    if not auth_data then
        ngx_log(ngx_WARN, "Malformed authorization header from: ", client_ip)
        return handle_auth_failure(client_ip, nil, false)
    end
    
    if handle_suspicious_pattern(auth_data, client_ip) then
        return send_challenge(false)
    end
    
    if handle_username_enumeration(auth_data, client_ip) then
        return send_challenge(false)
    end
    
    local success, stale = verify_credentials(auth_data)
    if not success then
        return handle_auth_failure(client_ip, auth_data, stale)
    end
    
    reset_rate_limit(client_ip)
    ngx_log(ngx_INFO, "Authentication successful for user: ", sanitize_log_value(auth_data.username), " from: ", sanitize_log_value(client_ip))
    return
end

-- Utility functions
function DigestAuth.clear_memory()
    if shared_memory then
        shared_memory:flush_all()
        ngx_log(ngx_INFO, "Cleared digest auth shared memory")
    end
    
    if rate_limit_memory then
        rate_limit_memory:flush_all()
        ngx_log(ngx_INFO, "Cleared rate limit shared memory")
    end
end

function DigestAuth.clear_nonces()
    if not shared_memory then
        return
    end
    
    local keys_to_delete = {}
    local i = 0
    
    while true do
        local keys, _ = shared_memory:get_keys(100, i)
        if not keys or #keys == 0 then break end
        
        for _, key in ipairs(keys) do
            if key:match("^nonce:") then
                table.insert(keys_to_delete, key)
            end
        end
        i = i + #keys
    end
    
    for _, key in ipairs(keys_to_delete) do
        shared_memory:delete(key)
    end
    
    ngx_log(ngx_INFO, "Cleared ", #keys_to_delete, " nonce entries")
end

function DigestAuth.cleanup_expired_nonces()
    if not shared_memory then return end
    local current_time = ngx.time()
    local keys_to_delete = {}
    local i = 0
    while true do
        local keys, _ = shared_memory:get_keys(100, i)
        if not keys or #keys == 0 then break end
        for _, key in ipairs(keys) do
            if key:match("^nonce:") then
                local encoded_metadata = shared_memory:get(key)
                if encoded_metadata then
                    local ok, metadata = pcall(cjson.decode, encoded_metadata)
                    if ok and metadata and metadata.timestamp then
                        if current_time - metadata.timestamp > (config.nonce_lifetime or 600) then
                            table.insert(keys_to_delete, key)
                        end
                    end
                end
            end
        end
        i = i + #keys
    end
    for _, key in ipairs(keys_to_delete) do
        shared_memory:delete(key)
    end
    ngx_log(ngx_INFO, "Cleaned up ", #keys_to_delete, " expired nonce entries")
end

return DigestAuth 
