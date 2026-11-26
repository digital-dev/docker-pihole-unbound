# pihole-unbound

![Docker Pulls](https://img.shields.io/docker/pulls/pestiience/pihole-unbound?style=flat&label=pulls&logo=docker) ![Docker Image Size](https://img.shields.io/docker/image-size/pestiience/pihole-unbound/latest?style=flat&logo=docker&label=image%20size) [![Weekly rebuild](https://img.shields.io/github/actions/workflow/status/digital-dev/docker-pihole-unbound/weekly-rebuild.yaml?style=flat&logo=github&label=weekly%20rebuild)](https://github.com/digital-dev/docker-pihole-unbound/actions/workflows/weekly-rebuild.yaml) ![GitHub Repo stars](https://img.shields.io/github/stars/digital-dev/docker-pihole-unbound?style=flat&logo=github)

[Pi-hole](https://github.com/pi-hole/pi-hole) v6 and [Unbound](https://github.com/NLnetLabs/unbound) in a single container: network-wide ad blocking plus your own recursive, DNSSEC-validating resolver, so your DNS queries don't go to a third-party upstream.

This is a community-maintained continuation of [origamiofficial/docker-pihole-unbound](https://github.com/origamiofficial/docker-pihole-unbound), which has been archived.

![banner](banner.png)

## What you get

* Official [`pihole/pihole`](https://hub.docker.com/r/pihole/pihole) **v6** (Alpine Linux) as the base
* Unbound built from source (checksum-verified) listening on `127.0.0.1:5335`; Pi-hole is pre-configured to use it
* **Rebuilt every Monday** with the latest Pi-hole and Unbound releases
* **Vulnerability-gated:** each build is scanned with [Trivy](https://trivy.dev/) and is only published if there are no fixable HIGH/CRITICAL findings
* Docker Hub image: [`pestiience/pihole-unbound`](https://hub.docker.com/r/pestiience/pihole-unbound)

## Supported architectures

| Architecture | Available | Platform |
| :----: | :----: | :----: |
| amd64 | ✅ | linux/amd64 |
| arm64 | ✅ | linux/arm64 |
| armhf / armel | ❌ | not built |

## Tags

| Tag | Meaning |
| :----: | :---- |
| `latest` | Most recent weekly build |
| `YYYY-MM-DD-unbound-X.Y.Z` | A specific build (date and Unbound version), for pinning or rollback |

> [!WARNING]
> **Coming from Pi-hole v5 or the original image?** Pi-hole v6 has breaking changes (e.g. `WEBPASSWORD` is now `FTLCONF_webserver_api_password`). Back up your data before upgrading. v5 settings are migrated automatically on first start. See the [Pi-hole v5 to v6 upgrade guide](https://docs.pi-hole.net/docker/upgrading/v5-v6/).

## Usage

### Docker run

```bash
docker run -d \
  --name pihole-unbound \
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

Use **separate** host folders for `/etc/pihole` and `/opt/unbound/etc/unbound`. Empty folders are fine: default Unbound files are created on first start and never overwritten afterwards.

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

```bash
docker compose up -d     # start
docker compose down      # stop
docker compose pull && docker compose up -d   # update
```

Add `cap_add: [NET_ADMIN]` if you use Pi-hole as a DHCP server.

### Unraid

In the Docker tab, add or edit the container, switch to **Advanced View**, and set:

| Setting | Value |
| :---- | :---- |
| Repository | `pestiience/pihole-unbound:latest` |
| Network Type | Custom (e.g. `br0`) with a fixed IP, or Bridge with port mappings |
| Variable `TZ` | Your timezone, e.g. `America/Chicago` |
| Variable `FTLCONF_webserver_api_password` | Web interface password (not `WEBPASSWORD`, which v6 ignores) |
| Path: container `/etc/pihole` | `/mnt/user/appdata/pihole-unbound/pihole` |
| Path: container `/opt/unbound/etc/unbound` | `/mnt/user/appdata/pihole-unbound/unbound` |
| Ports (Bridge mode only) | 53 TCP, 53 UDP, 80 TCP, 443 TCP |

Back up your appdata folder before switching from a v5 image. Unraid's *Check for updates* picks up the weekly rebuilds.

### Verify it works

```bash
# Unbound directly: should return NOERROR
docker exec pihole-unbound drill -p 5335 example.com @127.0.0.1
# DNSSEC validation: should return SERVFAIL
docker exec pihole-unbound drill -p 5335 dnssec-failed.org @127.0.0.1
```

Then point your router's DHCP DNS (or individual devices) at the container's IP.

## Parameters

| Parameter | Function |
| :---- | :---- |
| `-e TZ=America/Chicago` | Timezone |
| `-e FTLCONF_webserver_api_password=...` | Pi-hole web interface password |
| `-e FTLCONF_dns_upstreams=...` | Defaults to `127.0.0.1#5335` (the built-in Unbound). Changing it bypasses Unbound |
| `-p 53:53/tcp -p 53:53/udp` | DNS |
| `-p 80:80/tcp -p 443:443/tcp` | Pi-hole web interface |
| `-v <dir>:/etc/pihole` | Pi-hole data (settings, gravity database) |
| `-v <dir>:/opt/unbound/etc/unbound` | Unbound configuration |
| `--restart unless-stopped` | Keeps DNS up across reboots |

All [Pi-hole v6 environment variables](https://docs.pi-hole.net/docker/configuration/) (`FTLCONF_*`) are supported.

Files in the Unbound folder:

* `unbound.conf`: main config, generated on first start (delete it to regenerate)
* `a-records.conf`: local DNS records
* `srv-records.conf`: local SRV records
* `forward-records.conf`: optional DNS-over-TLS forwarding; uncomment its `include:` line in `unbound.conf` to use it

## Building it yourself

```bash
docker build -t pihole-unbound .
```

Optional build arguments: `BASE_IMG_TAG` (Pi-hole tag), `UNBOUND_VERSION` and `UNBOUND_SHA256` (checksum from `https://nlnetlabs.nl/downloads/unbound/unbound-<version>.tar.gz.sha256`).

To publish your own copy from GitHub Actions, fork this repository and add the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub access token with Read, Write & Delete scope). [`weekly-rebuild.yaml`](.github/workflows/weekly-rebuild.yaml) does the rest: it resolves the latest Unbound, builds, scans, pushes and updates the Docker Hub overview.

## Installing on Ubuntu

Modern Ubuntu releases include [`systemd-resolved`](http://manpages.ubuntu.com/manpages/bionic/man8/systemd-resolved.service.8.html), whose stub resolver listens on port 53 and stops Pi-hole from binding it. Disable the stub listener:

```bash
sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
sudo sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'
sudo systemctl restart systemd-resolved
```

Then configure your clients to use Pi-hole ([guide](https://discourse.pi-hole.net/t/how-do-i-configure-my-devices-to-use-pi-hole-as-their-dns-server/245)). To set the host's own nameserver explicitly, edit the netplan file in `/etc/netplan` and run `sudo netplan apply`:

```yaml
network:
    ethernets:
        ens160:
            dhcp4: true
            dhcp4-overrides:
                use-dns: false
            nameservers:
                addresses: [127.0.0.1]
    version: 2
```

## Links

* [Pi-hole Docker documentation](https://docs.pi-hole.net/docker/)
* [Pi-hole](https://github.com/pi-hole/pi-hole) and [docker-pi-hole](https://github.com/pi-hole/docker-pi-hole)
* [Unbound](https://github.com/NLnetLabs/unbound)
* [Docker Hub: pestiience/pihole-unbound](https://hub.docker.com/r/pestiience/pihole-unbound)

## Acknowledgements

Originally created by [OrigamiOfficial](https://github.com/origamiofficial/docker-pihole-unbound) (MIT license), influenced by MatthewVance's unbound-docker and chriscrowe's docker-pihole-unbound. Thanks to:

* [pi-hole](https://github.com/pi-hole)
* [NLnetLabs](https://github.com/NLnetLabs)
* [MatthewVance](https://github.com/MatthewVance)
* [chriscrowe](https://github.com/chriscrowe)
* [madnuttah](https://github.com/madnuttah)

Pi-hole is a trademark of Pi-hole LLC. This is an unofficial community image.

## Disclaimer

Use at your own risk. If your DNS goes down, so does your internet; keep a fallback resolver handy.
