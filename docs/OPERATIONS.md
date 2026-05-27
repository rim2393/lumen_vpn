# Operations

`configure.sh` creates or updates a private `/opt/lumen/.env`, asks for domains,
ACME email, first admin identity, registry settings, and validates domains and
loopback ports before install.

`doctor.sh` checks host tools, config validity, loopback port availability,
Compose rendering, pinned image syntax, Nginx, TLS files, and health endpoints.

`backup.sh` creates a PostgreSQL dump plus runtime config, secret files,
uploads, and runtime state. Backups contain secrets and should be encrypted with
`--passphrase-file`.

`restore.sh` is destructive and requires `--force`.

`upgrade.sh` consumes a signed release manifest, creates a pre-upgrade backup,
records previous image/env state, updates image references, runs migrations, and
starts the stack.

`rollback.sh` restores the last recorded pre-upgrade image/env state, or
delegates to `restore.sh` when a full encrypted backup is supplied.

`support-bundle.sh` creates sanitized diagnostics. Use `--redact-ips` before
sharing externally.
