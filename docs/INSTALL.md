# Install

Supported hosts: Debian 12 or Ubuntu 22.04/24.04 with systemd, root/sudo,
ports 80/443, public DNS, Docker Compose v2, Nginx, and acme.sh.

Real passwords and generated runtime configs must not be committed. Keep the
production config at a private path such as `/opt/lumen/.env` with mode `0600`.

1. Copy `.env.example` to a private path such as `/opt/lumen/.env`.
2. Set `PANEL_DOMAIN`, `SUBSCRIPTION_DOMAIN`, `ACME_EMAIL`, and timezone.
3. Replace zero image digests with signed release manifest values.
4. Put registry credentials in `REGISTRY_TOKEN_FILE` if private image pulls need it.
5. Run `sudo ./scripts/install.sh --config /opt/lumen/.env --dry-run`.
6. Run `sudo ./scripts/install.sh --config /opt/lumen/.env`.

## Dry-run config behavior

Dry-run is for command review and compose rendering. If the requested config file
does not exist, the installer reads `.env.example` and logs that it is using the
template. If a config contains `GENERATED_AT_INSTALL`, `GENERATE`, or
`CHANGE_ME`, dry-run logs which keys would be written but suppresses the values
and leaves the file unchanged.

The non-dry-run install is the step that writes generated secrets to the private
config file on the target host. Do not copy those values back into this repo.

For a two-server smoke run, start from `docs/TWO_SERVER_SMOKE.md`.
