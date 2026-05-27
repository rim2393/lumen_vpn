# Install

Supported hosts: Debian 12 or Ubuntu 22.04/24.04 with systemd, root/sudo,
ports 80/443, public DNS, Docker Compose v2, Nginx, and acme.sh.

1. Copy `.env.example` to a private path such as `/opt/lumen/.env`.
2. Set `PANEL_DOMAIN`, `SUBSCRIPTION_DOMAIN`, `ACME_EMAIL`, and timezone.
3. Replace zero image digests with signed release manifest values.
4. Put registry credentials in `REGISTRY_TOKEN_FILE` if private image pulls need it.
5. Run `sudo ./scripts/install.sh --config /opt/lumen/.env --dry-run`.
6. Run `sudo ./scripts/install.sh --config /opt/lumen/.env`.

Secrets are generated on the target host and must not be committed.

