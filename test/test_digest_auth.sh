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