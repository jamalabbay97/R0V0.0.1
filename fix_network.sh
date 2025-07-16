#!/bin/bash

echo "=== Network Connectivity Test ==="
echo "Testing connection to Maven Central..."

# Test DNS resolution
echo "1. Testing DNS resolution..."
nslookup repo.maven.apache.org

# Test HTTP connectivity
echo -e "\n2. Testing HTTP connectivity..."
curl -I --connect-timeout 10 https://repo.maven.apache.org/maven2/

# Test ping
echo -e "\n3. Testing ping..."
ping -c 3 repo.maven.apache.org

echo -e "\n=== Gradle Cache Cleanup ==="
echo "Cleaning Gradle cache..."
rm -rf ~/.gradle/caches/
rm -rf .gradle/
rm -rf build/

echo -e "\n=== Flutter Clean ==="
flutter clean

echo -e "\n=== Ready to retry build ==="
echo "Now try: flutter build apk --release" 