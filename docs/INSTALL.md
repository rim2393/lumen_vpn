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

`LUMEN_API_PORT`, `LUMEN_WEB_PORT`, and `LUMEN_SUBSCRIPTION_PORT` are
loopback host ports used by Nginx. `LUMEN_API_INTERNAL_PORT`,
`LUMEN_WEB_INTERNAL_PORT`, and `LUMEN_SUBSCRIPTION_INTERNAL_PORT` are container
ports exposed by the private images. The API image contract defaults to internal
port `8000`; Nginx still reaches it through host loopback port `8080`.

Production installs refuse unpinned or placeholder image digests. For a
pre-release smoke run against tag-only private images, set
`LUMEN_ALLOW_UNPINNED_IMAGES=true` in the private config or pass
`--allow-unpinned-images`. When that override is enabled, placeholder zero
digests from `.env.example` are reduced to tag-only image references before
Compose pulls. Remove the override before release validation.

## Dry-run config behavior

Dry-run is for command review before applying host changes. Pair it with
`docker compose --env-file <config> -f deploy/compose/lumen.yml config` when you
need a full compose render. If the requested config file does not exist, the
installer reads `.env.example` and logs that it is using the template. If a
config contains `GENERATED_AT_INSTALL`, `GENERATE`, or `CHANGE_ME`, dry-run logs
which keys would be written but suppresses the values and leaves the file
unchanged.

The non-dry-run install is the step that writes generated secrets to the private
config file on the target host. Do not copy those values back into this repo.

For a two-server smoke run, start from `docs/TWO_SERVER_SMOKE.md`.
