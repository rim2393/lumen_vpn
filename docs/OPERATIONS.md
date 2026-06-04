# Operations

`configure.sh` creates or updates a private `/opt/lumen/.env`, asks for domains,
ACME email, first admin identity, registry settings, and validates domains and
loopback ports before install.

`doctor.sh` checks host tools, config validity, loopback port availability,
Compose rendering, pinned image syntax, Nginx, TLS files, and health endpoints.

`backup.sh` creates a PostgreSQL dump plus runtime config, secret files,
uploads, and runtime state. Backups contain secrets and should be encrypted with
`--passphrase-file`. Backup retention is automatic: by default the installer
keeps the last 12 `lumen-backup-*` archives and the last 12 `upgrade-state`
directories. Override this with `LUMEN_BACKUP_RETENTION_COUNT` and
`LUMEN_UPGRADE_STATE_RETENTION_COUNT` in `/opt/lumen/.env` when a longer
rollback window is required.

`restore.sh` is destructive and requires `--force`.

`sign-manifest.sh` signs a pinned release manifest with an offline Ed25519
private key. `upgrade.sh` consumes that signed manifest, verifies it with
`LUMEN_RELEASE_PUBLIC_KEY_FILE`, checks `installer_min_version`, authenticates
to the configured registry when credentials are present, creates a pre-upgrade
backup, records previous image/env state, updates image references, runs
migrations, and starts the stack.

`rollback.sh` restores the last recorded pre-upgrade image/env state, or
delegates to `restore.sh` when a full encrypted backup is supplied.

`support-bundle.sh` creates sanitized diagnostics. Use `--redact-ips` before
sharing externally.

`publish-prod-release.yml` is the production promotion workflow. It receives a
private product image tag, resolves immutable GHCR digests, signs
`release/prod.json`, commits the official manifest, and deploys it to the panel
server through `upgrade.sh`. See `docs/PRODUCTION_RELEASES.md`.
