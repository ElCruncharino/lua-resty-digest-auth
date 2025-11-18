#!/bin/bash

# Performance testing script for lua-resty-digest-auth
BASE_URL="http://localhost:8080"
CONCURRENT_REQUESTS=50

echo "🚀 Performance Testing lua-resty-digest-auth module"
echo "=================================================="

# Test 1: Concurrent valid authentication requests
echo -e "\n1. Testing concurrent valid authentication requests..."
start_time=$(date +%s.%N)
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    curl -s -u "alice:password123" "$BASE_URL/protected/" > /dev/null &
done
wait
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
rps=$(echo "scale=2; $CONCURRENT_REQUESTS / $duration" | bc)
echo "   Completed $CONCURRENT_REQUESTS concurrent requests in ${duration}s (${rps} req/s)"

# Test 2: Sequential valid authentication requests
echo -e "\n2. Testing sequential valid authentication requests..."
start_time=$(date +%s.%N)
for i in $(seq 1 100); do
    curl -s -u "alice:password123" "$BASE_URL/protected/" > /dev/null
done
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
rps=$(echo "scale=2; 100 / $duration" | bc)
echo "   Completed 100 sequential requests in ${duration}s (${rps} req/s)"

# Test 3: Mixed valid/invalid authentication requests
echo -e "\n3. Testing mixed valid/invalid authentication requests..."
start_time=$(date +%s.%N)
for _ in $(seq 1 50); do
    curl -s -u "alice:password123" "$BASE_URL/protected/" > /dev/null &
    curl -s -u "alice:wrongpass" "$BASE_URL/protected/" > /dev/null &
done
wait
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
rps=$(echo "scale=2; 100 / $duration" | bc)
echo "   Completed 100 mixed requests in ${duration}s (${rps} req/s)"

# Test 4: Public endpoint performance (baseline)
echo -e "\n4. Testing public endpoint performance (baseline)..."
start_time=$(date +%s.%N)
for _ in $(seq 1 100); do
    curl -s "$BASE_URL/" > /dev/null
done
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
rps=$(echo "scale=2; 100 / $duration" | bc)
echo "   Completed 100 public requests in ${duration}s (${rps} req/s)"

# Test 5: Memory usage check
echo -e "\n5. Checking memory usage..."
docker exec lua-resty-digest-auth-test bash -c '
    echo "   OpenResty process memory usage:"
    ps aux | grep openresty | grep -v grep | awk "{print \$6/1024 \" MB\"}"
'

# Test 6: Load testing with Apache Bench (if available)
if command -v ab &> /dev/null; then
    echo -e "\n6. Load testing with Apache Bench..."
    ab -n 1000 -c 10 -u alice:password123 "$BASE_URL/protected/" 2>/dev/null | grep "Requests per second"
else
    echo -e "\n6. Apache Bench not available, skipping load test"
fi

echo -e "\n✅ Performance testing completed!" 