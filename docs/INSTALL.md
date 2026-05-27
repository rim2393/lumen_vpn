# Install

Supported hosts: Debian 12 or Ubuntu 22.04/24.04/26.04 with systemd, root/sudo,
ports 80/443, public DNS, Docker Compose v2, Nginx, and ACME HTTP-01 access.

Real passwords and generated runtime configs must not be committed. Keep the
production config at a private path such as `/opt/lumen/.env` with mode `0600`.

1. Run `sudo ./scripts/configure.sh --config /opt/lumen/.env` and answer the
   prompts for domains, ACME email, first admin identity, ports, and registry
   token file path.
2. Put registry credentials in `REGISTRY_TOKEN_FILE` if private image pulls need it.
3. Run `sudo ./scripts/install.sh --config /opt/lumen/.env --dry-run`.
4. Run `sudo ./scripts/install.sh --config /opt/lumen/.env`.

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

For a local-image smoke build on a private VPS, set `LUMEN_SKIP_IMAGE_PULL=true`
and point `LUMEN_API_IMAGE`, `LUMEN_WEB_IMAGE`, and subscription/node images at
the local tags already loaded into Docker.

If no certificate exists yet, the installer creates a temporary 14-day
self-signed bootstrap certificate so Nginx can start, then issues ACME
certificates with `acme.sh` when `LUMEN_ACME_ENABLED=true`. Set
`LUMEN_ACME_ENABLED=false` only for closed smoke runs with test domains.

Production installs reject example domains, duplicate loopback ports, and image
references without digest pins. If a loopback port is already listening, change
`LUMEN_API_PORT`, `LUMEN_WEB_PORT`, or `LUMEN_SUBSCRIPTION_PORT` before running
the installer. Use `LUMEN_SKIP_PORT_CHECK=true` only when another supervised
process intentionally owns the port during a controlled migration.

## Dry-run config behavior

Dry-run is for command review before applying host changes. Pair it with
`docker compose --env-file <config> -f deploy/compose/lumen.yml config` when you
need a full compose render. If the requested config file does not exist, the
installer reads `.env.example` and logs that it is using the template. If a
config contains `GENERATED_AT_INSTALL`, `GENERATE`, or `CHANGE_ME`, dry-run logs
which keys would be written but suppresses the values and leaves the file
unchanged.

The non-dry-run install is the step that writes generated secrets to the private
config file on the target host, runs database migrations, starts the stack, and
leaves the generated bootstrap admin API key only in `/opt/lumen/.env`. Do not
copy those values back into this repo.

## Upgrade and rollback

`upgrade.sh` accepts a signed release manifest, creates a pre-upgrade backup,
records the previous env under `$LUMEN_BACKUP_DIR/upgrade-state/<timestamp>`,
updates image pins, runs migrations, and restarts the stack.

Production release manifests are verified with Ed25519 before any backup,
image update, pull, or migration work starts. Put the trusted public key on the
host outside the repo and set `LUMEN_RELEASE_PUBLIC_KEY_FILE` in the private
config, for example `/opt/lumen/release-signing.pub`. The manifest signature is
computed over the canonical payload from `jq -cS 'del(.signature)'`.

Create the signed manifest on a trusted release machine. Keep the private key
outside the repo.

```bash
./scripts/sign-manifest.sh \
  --private-key-file /secure/release-signing.key \
  --kid lumen-release-2026-05 \
  --output /secure/lumen-release-v0.1.3.json \
  release/manifest.template.json
```

```bash
sudo ./scripts/upgrade.sh \
  --config /opt/lumen/.env \
  --manifest /secure/lumen-release-v0.1.3.json \
  --backup-passphrase-file /root/lumen-backup.pass
```

If the upgrade fails after image/env changes, roll back to the recorded compose
state:

```bash
sudo ./scripts/rollback.sh --config /opt/lumen/.env --force
```

For a full data restore, pass the encrypted backup explicitly:

```bash
sudo ./scripts/rollback.sh \
  --config /opt/lumen/.env \
  --backup /opt/lumen/backups/lumen-backup-YYYYMMDDTHHMMSSZ.tar.gz.enc \
  --passphrase-file /root/lumen-backup.pass \
  --force
```

For a two-server smoke run, start from `docs/TWO_SERVER_SMOKE.md`.
