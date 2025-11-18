#!/bin/bash

# Memory management function tests for lua-resty-digest-auth
BASE_URL="http://localhost:8080"

echo "Memory Management Function Tests"
echo "================================="

# Test 1: Test clear_nonces() function
echo -e "\n1. Testing clear_nonces() function..."
echo "   Generating some nonces..."
for i in {1..5}; do
    curl -s "$BASE_URL/protected/" > /dev/null
done

echo "   Calling clear_nonces endpoint..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/clear-nonces")
echo "   Status: $STATUS"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ clear_nonces() executed successfully"
else
    echo "   ✗ clear_nonces() failed or endpoint not available"
fi

echo "   Verifying nonces were cleared (new auth should work)..."
AUTH_STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Auth status: $AUTH_STATUS (should be 200)"

# Test 2: Test clear_memory() function
echo -e "\n2. Testing clear_memory() function..."
echo "   Creating some authentication attempts..."
for i in {1..3}; do
    curl -s --digest -u "alice:wrongpass" "$BASE_URL/protected/" > /dev/null
done

echo "   Calling clear_memory endpoint..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/clear-memory")
echo "   Status: $STATUS"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ clear_memory() executed successfully"
else
    echo "   ✗ clear_memory() failed or endpoint not available"
fi

echo "   Verifying memory was cleared (fresh start)..."
AUTH_STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Auth status: $AUTH_STATUS (should be 200)"

# Test 3: Test cleanup_expired_nonces() function
echo -e "\n3. Testing cleanup_expired_nonces() function..."
echo "   Generating nonces..."
for i in {1..5}; do
    curl -s "$BASE_URL/protected/" > /dev/null
done

echo "   Calling cleanup_expired_nonces endpoint..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/cleanup-expired")
echo "   Status: $STATUS"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ cleanup_expired_nonces() executed successfully"
else
    echo "   ✗ cleanup_expired_nonces() failed or endpoint not available"
fi

# Test 4: Memory usage before and after cleanup
echo -e "\n4. Testing memory usage impact..."
echo "   Creating high load to fill memory..."
for i in {1..100}; do
    curl -s "$BASE_URL/protected/" > /dev/null &
    curl -s --digest -u "user$i:wrongpass" "$BASE_URL/protected/" > /dev/null &
done
wait

echo "   Cleaning up expired nonces..."
curl -s "$BASE_URL/admin/cleanup-expired" > /dev/null

echo "   System should still be responsive..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
if [ "$STATUS" == "200" ]; then
    echo "   ✓ System responsive after cleanup"
else
    echo "   ✗ System issues after cleanup: $STATUS"
fi

# Test 5: Verify cleanup doesn't affect valid sessions
echo -e "\n5. Testing that cleanup preserves valid sessions..."
echo "   Authenticating successfully..."
curl -s --digest -u "alice:password123" "$BASE_URL/protected/" > /dev/null

echo "   Running cleanup..."
curl -s "$BASE_URL/admin/cleanup-expired" > /dev/null

echo "   Verifying auth still works..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 200)"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ Valid sessions preserved after cleanup"
else
    echo "   ✗ Cleanup may have affected valid sessions"
fi

echo -e "\nMemory management tests complete"
echo -e "\nNote: Some tests require admin endpoints in nginx.conf:"
echo "   - /admin/clear-nonces"
echo "   - /admin/clear-memory"
echo "   - /admin/cleanup-expired"
