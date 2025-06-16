#!/bin/bash

# Exit on any error
set -e

echo "Starting Squid-Warp proxy chain..."

# Create htpasswd file for authentication if credentials are provided
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    echo "Setting up authentication..."
    htpasswd -bc /etc/squid/passwd "$USERNAME" "$PASSWORD"
    echo "Authentication configured for user: $USERNAME"
fi

# Initialize Cloudflare WARP

echo "Initializing Cloudflare WARP..."

# Check if WARP is already registered
if ! warp-cli --accept-tos status | grep -q 'Registration'; then
    echo "Registering WARP..."
    warp-cli --accept-tos registration new
else
    echo "WARP already registered."
fi

warp-cli --accept-tos set-mode proxy
warp-cli --accept-tos set-proxy-port 40000
warp-cli --accept-tos connect

# Wait for WARP to be ready
echo "Waiting for WARP to be ready..."
sleep 10

# Check WARP status
echo "WARP Status:"
warp-cli --accept-tos status

# Test WARP connectivity
echo "Testing WARP connectivity..."
if curl -x socks5://127.0.0.1:40000 -s --max-time 10 https://cloudflare.com/cdn-cgi/trace | grep -q "warp=on"; then
    echo "WARP is working correctly!"
else
    echo "Warning: WARP might not be working properly"
fi

# Create necessary directories first
echo "Creating Squid directories..."
mkdir -p /var/log/squid
mkdir -p /var/spool/squid
mkdir -p /run/squid

# Set proper permissions
chown -R proxy:proxy /var/log/squid
chown -R proxy:proxy /var/spool/squid
chown -R proxy:proxy /run/squid

# Initialize squid cache
echo "Initializing Squid cache..."
squid -z -N

# Create a simple SOCKS5 to HTTP proxy converter script
cat > /usr/local/bin/socks2http.py << 'EOF'
#!/usr/bin/env python3
import socket
import threading
import select
import struct
import sys

def socks5_connect(target_host, target_port, socks_host='127.0.0.1', socks_port=40000):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((socks_host, socks_port))
    
    # SOCKS5 authentication
    sock.send(b'\x05\x01\x00')
    data = sock.recv(2)
    
    # Connect request
    request = b'\x05\x01\x00\x03' + bytes([len(target_host)]) + target_host.encode() + struct.pack('>H', target_port)
    sock.send(request)
    
    # Read response
    response = sock.recv(10)
    if response[1] != 0:
        raise Exception("SOCKS5 connection failed")
    
    return sock

def handle_client(client_socket):
    try:
        request = client_socket.recv(4096).decode('utf-8')
        lines = request.split('\n')
        first_line = lines[0]
        method, url, version = first_line.split(' ', 2)
        
        if method == 'CONNECT':
            host, port = url.split(':')
            port = int(port)
        else:
            if url.startswith('http://'):
                url = url[7:]
            host = url.split('/')[0]
            if ':' in host:
                host, port = host.split(':')
                port = int(port)
            else:
                port = 80
        
        # Connect through SOCKS5
        upstream = socks5_connect(host, port)
        
        if method == 'CONNECT':
            client_socket.send(b'HTTP/1.1 200 Connection established\r\n\r\n')
        else:
            upstream.send(request.encode())
        
        # Relay data
        def relay(src, dst):
            try:
                while True:
                    ready, _, _ = select.select([src], [], [], 1)
                    if ready:
                        data = src.recv(4096)
                        if not data:
                            break
                        dst.send(data)
            except:
                pass
        
        t1 = threading.Thread(target=relay, args=(client_socket, upstream))
        t2 = threading.Thread(target=relay, args=(upstream, client_socket))
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        
    except Exception as e:
        pass
    finally:
        client_socket.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 8080))
    server.listen(5)
    
    while True:
        client, addr = server.accept()
        thread = threading.Thread(target=handle_client, args=(client,))
        thread.daemon = True
        thread.start()

if __name__ == '__main__':
    main()
EOF

chmod +x /usr/local/bin/socks2http.py

# Start the SOCKS5 to HTTP proxy converter
echo "Starting SOCKS5 to HTTP proxy converter..."
python3 /usr/local/bin/socks2http.py &
sleep 3

# Start Squid in foreground
echo "Starting Squid proxy..."
exec squid -N -f /etc/squid/squid.conf
