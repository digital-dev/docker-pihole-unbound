# Pi-hole v6 + Unbound in one container

Community-maintained rebuild of [origamiofficial/docker-pihole-unbound](https://github.com/origamiofficial/docker-pihole-unbound), which is no longer updated.

* Based on the official [`pihole/pihole`](https://hub.docker.com/r/pihole/pihole) **v6** image (Alpine Linux)
* [Unbound](https://nlnetlabs.nl/projects/unbound/about/) recursive resolver built from source, with DNSSEC validation, listening on `127.0.0.1:5335` inside the container; Pi-hole is already pointed at it
* **Rebuilt weekly** with the latest Pi-hole base and latest Unbound release, scanned with [Trivy](https://trivy.dev/); the image is only published if there are no fixable HIGH/CRITICAL vulnerabilities
* Architectures: `linux/amd64`, `linux/arm64`

Source and build workflow: <https://github.com/digital-dev/docker-pihole-unbound>

## Tags

| Tag | Meaning |
|---|---|
| `latest` | Most recent weekly build |
| `YYYY-MM-DD-unbound-X.Y.Z` | A specific build (date and Unbound version), for pinning or rollback |

> **Upgrading from Pi-hole v5?** v6 has breaking changes (environment variable names, API/password handling, config format). Back up your data first. v5 settings are migrated automatically on first start. See the [Pi-hole v6 docs](https://docs.pi-hole.net/docker/upgrading/v5-v6/).

## Quick start (Docker)

```bash
docker run -d --name pihole-unbound \
  -p 53:53/tcp -p 53:53/udp \
  -p 80:80/tcp -p 443:443/tcp \
  -e TZ="America/Chicago" \
  -e FTLCONF_webserver_api_password="change-me" \
  -v /opt/pihole-unbound/pihole:/etc/pihole \
  -v /opt/pihole-unbound/unbound:/opt/unbound/etc/unbound \
  --restart unless-stopped \
  pestiience/pihole-unbound:latest
```

Web interface: `http://<host-ip>/admin`

### Docker Compose

```yaml
services:
  pihole-unbound:
    image: pestiience/pihole-unbound:latest
    container_name: pihole-unbound
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "443:443/tcp"
    environment:
      TZ: "America/Chicago"
      FTLCONF_webserver_api_password: "change-me"
    volumes:
      - ./pihole:/etc/pihole
      - ./unbound:/opt/unbound/etc/unbound
    restart: unless-stopped
```

Optional: add `cap_add: [NET_ADMIN]` if you use Pi-hole as a DHCP server.

## Unraid

Edit (or create) the container in the Docker tab, switch to **Advanced View**, and set:

| Setting | Value |
|---|---|
| Repository | `pestiience/pihole-unbound:latest` |
| Network Type | Custom (e.g. `br0`) with a fixed IP, or Bridge with port mappings |
| Variable `TZ` | Your timezone, e.g. `America/Chicago` |
| Variable `FTLCONF_webserver_api_password` | Web interface password (**not** `WEBPASSWORD`, which v6 ignores) |
| Path: container `/etc/pihole` | `/mnt/user/appdata/pihole-unbound/pihole` |
| Path: container `/opt/unbound/etc/unbound` | `/mnt/user/appdata/pihole-unbound/unbound` |
| Ports (Bridge mode only) | 53 TCP, 53 UDP, 80 TCP, 443 TCP |

Keep the two paths in **separate** folders. Back up the appdata folder before switching from a v5 image.

Updates: Unraid's *Check for updates* detects the weekly rebuild; click *apply update* to pull it.

## Configuration

| Variable | Purpose |
|---|---|
| `TZ` | Timezone |
| `FTLCONF_webserver_api_password` | Web interface password |
| `FTLCONF_dns_upstreams` | Defaults to `127.0.0.1#5335` (the built-in Unbound). Changing it bypasses Unbound |
| `FTLCONF_*` | Any other [Pi-hole v6 setting](https://docs.pi-hole.net/docker/configuration/) |

Unbound files in `/opt/unbound/etc/unbound` (created from defaults on first start; yours are never overwritten):

* `unbound.conf`: main config (generated on first start; delete it to regenerate)
* `a-records.conf`: local DNS records
* `srv-records.conf`: local SRV records
* `forward-records.conf`: optional DNS-over-TLS forwarding (uncomment the include in `unbound.conf` to use it)

## Verify it works

```bash
# Unbound directly (should return NOERROR)
docker exec pihole-unbound drill -p 5335 example.com @127.0.0.1
# DNSSEC validation (should return SERVFAIL)
docker exec pihole-unbound drill -p 5335 dnssec-failed.org @127.0.0.1
```

Then point your router's DHCP DNS (or devices) at the container's IP.

## Credits

Original project by [OrigamiOfficial](https://github.com/origamiofficial/docker-pihole-unbound) (MIT). Pi-hole is a trademark of Pi-hole LLC. This is an unofficial community image.
