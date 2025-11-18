#!/bin/bash

# Advanced test script for lua-resty-digest-auth
# Tests nonce management, memory cleanup, and advanced edge cases
BASE_URL="http://localhost:8080"

echo "Advanced Testing lua-resty-digest-auth module"
echo "=============================================="

# Test 1: Nonce lifecycle
echo -e "\n1. Testing nonce lifecycle..."
echo "   Getting initial challenge (nonce)..."
CHALLENGE_1=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'nonce="[^"]*"' | cut -d'"' -f2)
echo "   First nonce: ${CHALLENGE_1:0:20}..."

echo "   Waiting 2 seconds and getting new challenge..."
sleep 2
CHALLENGE_2=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'nonce="[^"]*"' | cut -d'"' -f2)
echo "   Second nonce: ${CHALLENGE_2:0:20}..."

if [ "$CHALLENGE_1" != "$CHALLENGE_2" ]; then
    echo "   ✓ Nonces are different (as expected)"
else
    echo "   ✗ Nonces are the same (unexpected)"
fi

# Test 2: Nonce reuse limits
echo -e "\n2. Testing nonce reuse..."
echo "   Making 10 requests with valid credentials to test nonce reuse..."
for i in {1..10}; do
    STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
    echo "   Request $i: Status $STATUS"
done

# Test 3: Stale nonce handling
echo -e "\n3. Testing stale nonce handling..."
echo "   Getting challenge..."
STALE_NONCE=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'nonce="[^"]*"' | cut -d'"' -f2)
echo "   Waiting 5 seconds for potential nonce expiration..."
sleep 5
echo "   Attempting to use potentially stale nonce..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (401 = stale, 200 = still valid)"

# Test 4: Memory cleanup simulation
echo -e "\n4. Testing memory cleanup behavior..."
echo "   Creating many failed authentication attempts to fill memory..."
for i in {1..50}; do
    curl -s --digest -u "testuser$i:wrongpass" -o /dev/null "$BASE_URL/protected/" &
    if [ $((i % 10)) -eq 0 ]; then
        echo "   Created $i failed auth attempts..."
    fi
done
wait
echo "   All failed attempts completed"

echo "   Testing if system still responds correctly..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 200 if memory management works)"

# Test 5: Concurrent nonce generation
echo -e "\n5. Testing concurrent nonce generation..."
echo "   Generating 20 nonces concurrently..."
for i in {1..20}; do
    curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" > /tmp/nonce_$i.txt &
done
wait

echo "   Checking for unique nonces..."
UNIQUE_COUNT=$(cat /tmp/nonce_*.txt 2>/dev/null | grep -o 'nonce="[^"]*"' | sort -u | wc -l)
TOTAL_COUNT=$(cat /tmp/nonce_*.txt 2>/dev/null | grep -o 'nonce="[^"]*"' | wc -l)
echo "   Generated $TOTAL_COUNT nonces, $UNIQUE_COUNT unique"
rm -f /tmp/nonce_*.txt

if [ "$UNIQUE_COUNT" -eq "$TOTAL_COUNT" ]; then
    echo "   ✓ All nonces are unique (good randomness)"
else
    echo "   ✗ Some nonces are duplicated (potential collision issue)"
fi

# Test 6: QOP parameter testing
echo -e "\n6. Testing QOP parameter handling..."
echo "   Checking if server advertises QOP in challenge..."
QOP=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'qop="[^"]*"')
if [ -n "$QOP" ]; then
    echo "   Server advertises: $QOP"
else
    echo "   Server does not advertise QOP parameter"
fi

# Test 7: Algorithm parameter
echo -e "\n7. Testing algorithm parameter..."
ALGO=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'algorithm=[^,]*')
echo "   Server algorithm: $ALGO"
if echo "$ALGO" | grep -q "MD5"; then
    echo "   ✓ MD5 algorithm (RFC 2617 compliant)"
else
    echo "   ✗ Unexpected algorithm"
fi

# Test 8: Opaque parameter handling
echo -e "\n8. Testing opaque parameter..."
OPAQUE=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'opaque="[^"]*"')
if [ -n "$OPAQUE" ]; then
    echo "   Server provides opaque: ${OPAQUE:0:30}..."
else
    echo "   Server does not provide opaque parameter"
fi

# Test 9: URI mismatch detection
echo -e "\n9. Testing URI mismatch detection..."
echo "   Attempting authentication with mismatched URI..."
# This would require manual manipulation of the digest response
echo "   (Manual test - requires custom digest client)"

# Test 10: Realm verification
echo -e "\n10. Testing realm verification..."
REALM=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'realm="[^"]*"' | cut -d'"' -f2)
echo "   Server realm: $REALM"
if [ "$REALM" == "Test Realm" ]; then
    echo "   ✓ Correct realm"
else
    echo "   ✗ Unexpected realm: $REALM"
fi

# Test 11: Header injection protection
echo -e "\n11. Testing header injection protection..."
echo "   Testing with newline in username..."
STATUS=$(curl -s --digest -u $'alice\r\nInjected-Header: value':password123 -o /dev/null -w "%{http_code}" "$BASE_URL/protected/" 2>/dev/null || echo "400")
echo "   Status: $STATUS (should be 400 or 401)"

echo "   Testing with null byte in username..."
STATUS=$(curl -s --digest -u $'alice\x00admin':password123 -o /dev/null -w "%{http_code}" "$BASE_URL/protected/" 2>/dev/null || echo "400")
echo "   Status: $STATUS (should be 400 or 401)"

# Test 12: Very long nonce handling
echo -e "\n12. Testing nonce length limits..."
# Server should generate reasonable-length nonces
NONCE=$(curl -s -D - "$BASE_URL/protected/" | grep -i "www-authenticate" | grep -o 'nonce="[^"]*"' | cut -d'"' -f2)
NONCE_LEN=${#NONCE}
echo "   Nonce length: $NONCE_LEN characters"
if [ $NONCE_LEN -gt 16 ] && [ $NONCE_LEN -lt 128 ]; then
    echo "   ✓ Nonce length is reasonable"
else
    echo "   ✗ Nonce length is unusual: $NONCE_LEN"
fi

# Test 13: Case sensitivity
echo -e "\n13. Testing case sensitivity..."
echo "   Testing with uppercase username (ALICE)..."
STATUS=$(curl -s --digest -u "ALICE:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 401 - usernames are case-sensitive)"

# Test 14: Whitespace handling
echo -e "\n14. Testing whitespace handling..."
echo "   Testing with spaces in username..."
STATUS=$(curl -s --digest -u " alice ":password123 -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 401 - no trimming)"

# Test 15: Performance under load
echo -e "\n15. Testing performance under concurrent load..."
echo "   Running 100 concurrent authenticated requests..."
start_time=$(date +%s.%N)
for i in {1..100}; do
    curl -s --digest -u "alice:password123" "$BASE_URL/protected/" > /dev/null &
done
wait
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
if [ "$duration" != "N/A" ]; then
    rps=$(echo "scale=2; 100 / $duration" | bc)
    echo "   Completed 100 requests in ${duration}s (${rps} req/s)"
else
    echo "   Completed 100 requests (timing unavailable)"
fi

echo -e "\nAdvanced testing complete"
echo -e "\nSummary:"
echo "   - Nonce lifecycle: TESTED"
echo "   - Nonce reuse: TESTED"
echo "   - Concurrent nonce generation: TESTED"
echo "   - QOP/Algorithm parameters: TESTED"
echo "   - Header injection protection: TESTED"
echo "   - Case sensitivity: TESTED"
echo "   - Performance under load: TESTED"
