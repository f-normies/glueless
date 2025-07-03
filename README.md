# GlueLESS

**IMPORTANT: THIS IS A MVP AND IS NOT READY FOR PRODUCTION.** Please consider contributing for this project :)

A lightweight Docker container that routes traffic through VLESS Xray-XTLS protocol, maintaining compatibility with gluetun's interface patterns for seamless integration with existing docker-compose setups.

## Features

- **Gluetun-compatible interface**: Same capability requirements and device mounts
- **Traffic routing**: RedSocks + iptables for reliable transparent proxying
- **Lightweight**: Based on Alpine Linux for minimal footprint

## Quick Start

1. **Configure your VLESS and Hiddify configurations** (learn more on hiddify-core [repository](https://github.com/hiddify/hiddify-core) and [website](https://hiddify.com/app/HiddifyCli-guide/))

2. **Start the container**:
   ```bash
   sudo docker compose up -d
   ```

3. **Test the connection**:
   ```bash
   # Run the test suite
   sudo docker compose -f docker-compose.test.yml --profile test up test-client
   ```

## Configuration

### VLESS Server Configuration

Edit `proxy-config.json` with your VLESS server details. Barebones example:

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-server",
      "server": "your-server-ip",
      "server_port": 443,
      "uuid": "your-uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "your-sni",
        "reality": {
          "enabled": true,
          "public_key": "your-public-key",
          "short_id": "your-short-id"
        }
      }
    }
  ]
}
```

### Client Configuration

Edit `hiddify-config.json` to adjust client settings like DNS and routing rules. **Changing ports is highly not recommended**.

## Usage with Other Containers

### Method 1: Service Network Mode (Recommended - Full VPN)

ALL of the traffic from containers using this network mode will automatically go through the VPN:

```yaml
services:
  glueless:
    image: ghcr.io/f-normies/glueless:latest
    cap_add:
      - NET_ADMIN
    volumes:
      - ./hiddify-config.json:/hiddify/hiddify-config.json
      - ./proxy-config.json:/hiddify/proxy-config.json

  your-app:
    image: your-app:latest
    network_mode: "service:glueless"
    depends_on:
      - glueless
```

A simple `curl ipinfo.io` from your-app will show the VPN server's IP, not your real IP.

### Method 2: Proxy Configuration

Traffic from apps that support proxies env variables will be routed through VPN, otherwise direct connection will be established.

```yaml
services:
  glueless:
    image: ghcr.io/f-normies/glueless:latest
    cap_add:
      - NET_ADMIN
    volumes:
      - ./hiddify-config.json:/hiddify/hiddify-config.json
      - ./proxy-config.json:/hiddify/proxy-config.json
    ports:
      - "12334:12334"

  your-app:
    image: your-app:latest
    environment:
      - HTTP_PROXY=http://glueless:12334
      - HTTPS_PROXY=http://glueless:12334
``` 

*Although this isn't intended use for this app and is not tested.*

## Troubleshooting

### Connection Issues
- Check logs: `docker logs glueless`
- Verify VLESS server configuration
- Ensure server is reachable
- If `network-mode` is used and geoip redirections configured for direct connect connection for such service will not resolve, this **maybe** will be addressed in next versions

### Permission Issues
- Ensure `NET_ADMIN` capability is added

### Network Problems
- Check iptables rules: `docker exec glueless iptables -t mangle -L`
- Verify IP forwarding: `docker exec glueless sysctl net.ipv4.ip_forward`

## Requirements

- Docker with capability support
- NET_ADMIN capability for RedSocks + iptables transparent proxy

## Credits

- [XTLS community](https://github.com/XTLS) for implementing and supporting [Xray-core](https://github.com/XTLS/Xray-core)
- [Hiddify](https://github.com/hiddify) for creating such versatile client

## License

This project is open source. See the LICENSE file for details.