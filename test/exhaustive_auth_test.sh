#!/bin/bash

# Exhaustive test script for lua-resty-digest-auth
BASE_URL="http://localhost:8080"

echo "Exhaustive Testing lua-resty-digest-auth module"
echo "================================================"

# 1. Nested route (should require auth)
echo -e "1. Testing nested protected route (expecting 401)..."
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/nested/route"

echo -e "\n2. Testing nested protected route with valid credentials..."
curl -s --digest -u "alice:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/nested/route"

# 2. Multiple failed logins (rate limiting)
echo -e "\n3. Testing rate limiting with multiple failed logins..."
for i in {1..12}; do
  curl -s --digest -u "alice:wrongpassword" -o /dev/null -w "Attempt $i: Status: %{http_code}\n" "$BASE_URL/protected/"
done

echo -e "\n4. Testing after rate limit lockout (should be 403)..."
curl -s --digest -u "alice:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 3. Malformed/missing headers
echo -e "\n5. Testing with missing Authorization header..."
curl -s -H "Authorization:" -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/"

echo -e "\n6. Testing with malformed Authorization header..."
curl -s -H "Authorization: Digest thisisnotvalid" -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 4. Edge cases: empty username, special chars, long credentials
echo -e "\n7. Testing with empty username..."
curl -s --digest -u ":password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

echo -e "\n8. Testing with special characters in username..."
curl -s --digest -u "ali!@#ce:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

echo -e "\n9. Testing with very long username..."
LONGUSER=$(head -c 256 </dev/urandom | base64)
curl -s --digest -u "$LONGUSER:password123" -w "Status: %{http_code}\n" "$BASE_URL/protected/"

# 5. Nonce replay (reuse same digest response)
echo -e "\n10. Testing nonce replay (manual step required, see below)"
echo "   - Use a tool like curl or Postman to capture a valid Digest Authorization header, then reuse it."
echo "   - This script cannot automate nonce replay without parsing challenge/response."

echo -e "\n11. Simultaneous requests (basic concurrency test)..."
for i in {1..5}; do
  curl -s --digest -u "alice:password123" "$BASE_URL/protected/" &
done
wait
echo "All concurrent requests completed."

echo -e "\nExhaustive testing complete" 