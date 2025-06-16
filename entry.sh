#!/bin/sh
set -xe

# 1. Create required directories with proper permissions
mkdir -p /run/squid /var/cache/squid /var/log/squid
chown -R proxy:proxy /run/squid /var/cache/squid /var/log/squid

# 2. Start WARP service
env RUST_LOG=error warp-svc >/dev/null 2>&1 &
WARP_PID=$!

# 3. Wait for warp-cli availability
until warp-cli --accept-tos status >/dev/null 2>&1; do
  sleep 1
done

# 4. Clean previous registration (ignore errors)
warp-cli --accept-tos registration delete || true

# 5. Register headlessly
warp-cli --accept-tos registration new

# 6. Configure WARP as local proxy
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40001
warp-cli --accept-tos connect

# 7. Verify WARP connection
until warp-cli --accept-tos status | grep -q "Connected"; do
  echo "Waiting for WARP connection..."
  sleep 1
done

# 8. Setup Squid credentials
htpasswd -cb /etc/squid/passwd "${USERNAME}" "${PASSWORD}"
chown proxy:proxy /etc/squid/passwd

# 9. Initialize Squid cache
su -s /bin/sh proxy -c "squid -z -f /etc/squid/squid.conf" || true

# 10. Start Squid in foreground
exec su -s /bin/sh proxy -c "squid -N -f /etc/squid/squid.conf"
