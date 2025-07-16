#!/bin/bash

# Exhaustive test script for lua-resty-digest-auth
BASE_URL="http://localhost:8080"

set -e

echo "🧪 Exhaustive Testing lua-resty-digest-auth module..."
echo "===============================================\n"

# 1. Nested route (should require auth)
printf "1. Testing nested protected route (expecting 401)...\n"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/nested/route"

printf "\n2. Testing nested protected route with valid credentials...\n"
curl -s -u "alice:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/nested/route"

# 2. Multiple failed logins (rate limiting)
printf "\n3. Testing rate limiting with multiple failed logins...\n"
for i in {1..12}; do
  curl -s -u "alice:wrongpassword" -o /dev/null -w "Attempt $i: Status: %{http_code}\n" "$BASE_URL/protected/"
done

printf "\n4. Testing after rate limit lockout (should be 403)...\n"
curl -s -u "alice:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 3. Malformed/missing headers
printf "\n5. Testing with missing Authorization header...\n"
curl -s -H "Authorization:" -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/"

printf "\n6. Testing with malformed Authorization header...\n"
curl -s -H "Authorization: Digest thisisnotvalid" -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 4. Edge cases: empty username, special chars, long credentials
printf "\n7. Testing with empty username...\n"
curl -s -u ":password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

printf "\n8. Testing with special characters in username...\n"
curl -s -u "ali!@#ce:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

printf "\n9. Testing with very long username...\n"
LONGUSER=$(head -c 256 </dev/urandom | base64)
curl -s -u "$LONGUSER:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 5. Nonce replay (reuse same digest response)
printf "\n10. Testing nonce replay (manual step required, see below)\n"
printf "   - Use a tool like curl or Postman to capture a valid Digest Authorization header, then reuse it.\n"
printf "   - This script cannot automate nonce replay without parsing challenge/response.\n"

printf "\n11. Simultaneous requests (basic concurrency test)...\n"
for i in {1..5}; do
  curl -s -u "alice:password123" "$BASE_URL/protected/" &
done
wait
echo "All concurrent requests completed."

printf "\n✅ Exhaustive testing complete!\n"