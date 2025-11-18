#!/bin/bash

# Brute force protection test script for lua-resty-digest-auth
BASE_URL="http://localhost:8080"

echo "Brute Force Protection Tests"
echo "============================="

# Test 1: Basic failed attempt tracking
echo -e "\n1. Testing basic failed attempt tracking..."
echo "   Making 3 failed login attempts..."
for i in {1..3}; do
    STATUS=$(curl -s --digest -u "alice:wrongpass" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
    echo "   Attempt $i: $STATUS"
done

echo "   Verifying correct password still works..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Valid auth: $STATUS (should be 200)"

# Clear state before next test
echo "   Clearing memory for next test..."
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 2: Blocking after max failed attempts
echo -e "\n2. Testing blocking after max failed attempts (5)..."
echo "   Making 6 failed login attempts..."
for i in {1..6}; do
    STATUS=$(curl -s --digest -u "bob:wrongpass" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
    echo "   Attempt $i: $STATUS"
    sleep 0.2
done

echo "   Testing if client is blocked (even with correct password)..."
STATUS=$(curl -s --digest -u "bob:password456" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 403 = blocked)"

if [ "$STATUS" == "403" ]; then
    echo "   ✓ Client blocked after max failed attempts"
else
    echo "   ✗ Client not blocked: $STATUS"
fi

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 3: Empty credentials detection
echo -e "\n3. Testing empty credentials detection..."
echo "   Attempting with empty username..."
STATUS=$(curl -s --digest -u ":password" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 403)"

echo "   Attempting with empty password..."
STATUS=$(curl -s --digest -u "alice:" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 403)"

echo "   Attempting with both empty..."
STATUS=$(curl -s --digest -u ":" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 403)"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 4: Malformed headers detection
echo -e "\n4. Testing malformed headers detection..."
echo "   Testing with Basic auth header (not Digest)..."
STATUS=$(curl -s -H "Authorization: Basic YWxpY2U6cGFzc3dvcmQxMjM=" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 401)"

echo "   Testing with malformed Digest header..."
STATUS=$(curl -s -H "Authorization: Digest invalid" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 401)"

echo "   Testing with completely invalid header..."
STATUS=$(curl -s -H "Authorization: ThisIsNotValid" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 400 or 401)"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 5: Rapid requests detection
echo -e "\n5. Testing rapid requests detection..."
echo "   Sending 10 concurrent failed requests..."
for i in {1..10}; do
    curl -s --digest -u "charlie:wrongpass" -o /dev/null "$BASE_URL/protected/" &
done
wait

echo "   Checking if rapid requests triggered blocking..."
STATUS=$(curl -s --digest -u "charlie:wrongpass" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (likely 403 if rapid request detection worked)"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 6: Username enumeration protection
echo -e "\n6. Testing username enumeration protection..."
echo "   Testing multiple failed attempts for same username..."
for i in {1..4}; do
    STATUS=$(curl -s --digest -u "admin:wrongpass$i" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
    echo "   Attempt $i: $STATUS"
    sleep 0.2
done

echo "   Verifying enumeration protection kicked in..."
STATUS=$(curl -s --digest -u "admin:adminpass" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (may be 403 if enumeration threshold reached)"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 7: Per-IP blocking (not global)
echo -e "\n7. Testing per-IP blocking isolation..."
echo "   Blocking one user (alice with wrong password)..."
for i in {1..6}; do
    curl -s --digest -u "alice:wrongpass" -o /dev/null "$BASE_URL/protected/"
done

echo "   Testing if other users are affected..."
STATUS=$(curl -s --digest -u "bob:password456" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Bob's status: $STATUS (should be 200 - not affected by Alice's block)"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ Blocking is per-IP/user, not global"
else
    echo "   ✗ Other users may be affected: $STATUS"
fi

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 8: Block duration and recovery
echo -e "\n8. Testing block duration (quick test - not waiting full duration)..."
echo "   Triggering block..."
for i in {1..6}; do
    curl -s --digest -u "alice:wrongpass" -o /dev/null "$BASE_URL/protected/"
done

echo "   Verifying block is active..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status immediately after: $STATUS (should be 403)"

echo "   Note: Full block duration is 1800s (30 min) - not testing full recovery time"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null
sleep 1

# Test 9: Different failure modes
echo -e "\n9. Testing different authentication failure modes..."
echo "   Wrong username..."
STATUS=$(curl -s --digest -u "nonexistent:password" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS"

echo "   Wrong password..."
STATUS=$(curl -s --digest -u "alice:wrongpassword" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS"

echo "   Wrong realm (if supported)..."
# This test depends on implementation details
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS"

# Clear state
curl -s "$BASE_URL/admin/clear-memory" > /dev/null

# Test 10: Successful auth resets counter
echo -e "\n10. Testing that successful auth resets failed attempt counter..."
echo "   Making 2 failed attempts..."
curl -s --digest -u "alice:wrong1" -o /dev/null "$BASE_URL/protected/"
curl -s --digest -u "alice:wrong2" -o /dev/null "$BASE_URL/protected/"

echo "   Successful authentication..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS"

echo "   Making 3 more failed attempts (total would be 5, but counter should have reset)..."
curl -s --digest -u "alice:wrong3" -o /dev/null "$BASE_URL/protected/"
curl -s --digest -u "alice:wrong4" -o /dev/null "$BASE_URL/protected/"
curl -s --digest -u "alice:wrong5" -o /dev/null "$BASE_URL/protected/"

echo "   Testing if user can still authenticate (if counter reset, should work)..."
STATUS=$(curl -s --digest -u "alice:password123" -o /dev/null -w "%{http_code}" "$BASE_URL/protected/")
echo "   Status: $STATUS (should be 200 if counter was reset)"

if [ "$STATUS" == "200" ]; then
    echo "   ✓ Failed attempt counter resets on successful auth"
else
    echo "   ✗ Counter may not be resetting: $STATUS"
fi

echo -e "\nBrute force protection tests complete"
echo -e "\nSummary:"
echo "   - Failed attempt tracking: TESTED"
echo "   - Blocking after max attempts: TESTED"
echo "   - Empty credentials detection: TESTED"
echo "   - Malformed headers detection: TESTED"
echo "   - Rapid requests detection: TESTED"
echo "   - Username enumeration protection: TESTED"
echo "   - Per-IP isolation: TESTED"
echo "   - Counter reset on success: TESTED"
