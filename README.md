# Squid Warp Proxy Chain

This project creates a proxy chain that routes traffic through Squid proxy and then through Cloudflare WARP. This provides an additional layer of privacy and can help bypass certain network restrictions.

## Architecture

```
Client → Squid Proxy (Port 3128) → SOCKS5-to-HTTP Converter (Port 8080) → WARP SOCKS5 Proxy (Port 40000) → Internet
```

## Quick Start

1. **Build and start the service:**
   ```bash
   ./test-proxy.sh
   ```

2. **Test the proxy:**
   ```bash
   curl -x http://mehdi:hadi@localhost:8082 https://cloudflare.com/cdn-cgi/trace
   ```
   
   You should see `warp=on` in the output if everything is working correctly.

## Configuration

### Authentication
- Username: `mehdi` (configurable via `USERNAME` env var)
- Password: `hadi` (configurable via `PASSWORD` env var)

### Ports
- External port: `8082` (maps to internal port 3128)
- Internal WARP SOCKS5: `40000`
- Internal HTTP converter: `8080`

## Troubleshooting

### Check container logs:
```bash
docker-compose logs -f
```

### Check if WARP is connected:
```bash
docker-compose exec proxy warp-cli status
```

### Manual testing inside container:
```bash
docker-compose exec proxy bash
curl -x socks5://127.0.0.1:40000 https://cloudflare.com/cdn-cgi/trace
```

## Files

- `docker-compose.yml` - Service configuration
- `Dockerfile` - Container build instructions
- `entry.sh` - Startup script that initializes WARP and Squid
- `squid.conf` - Squid proxy configuration
- `test-proxy.sh` - Quick test script

## Environment Variables

- `USERNAME` - Proxy authentication username (default: mehdi)
- `PASSWORD` - Proxy authentication password (default: hadi)

## Usage Examples

### Browser Configuration
Configure your browser to use HTTP proxy:
- Server: `localhost`
- Port: `8082`
- Username: `mehdi`
- Password: `hadi`

### Command Line
```bash
curl -x http://mehdi:hadi@localhost:8082 https://example.com
wget --proxy-user=mehdi --proxy-password=hadi -e use_proxy=yes -e http_proxy=localhost:8082 https://example.com
```

