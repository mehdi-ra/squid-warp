#!/bin/bash

echo "Building and starting the Squid-Warp proxy chain..."

# Build the Docker image
docker compose build

# Start the service
docker compose up -d

echo "Waiting for services to start..."
sleep 20

# Test the proxy
echo "Testing the proxy chain..."
echo "You can test the proxy with:"
echo "curl -x http://mehdi:hadi@localhost:8082 https://cloudflare.com/cdn-cgi/trace"
echo ""
echo "Expected output should show 'warp=on' if the chain is working correctly"

# Check container logs
echo "Container logs:"
docker-compose logs --tail=50
