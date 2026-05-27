# Operations

`doctor.sh` checks host tools, Compose rendering, pinned image syntax, Nginx,
TLS files, and health endpoints.

`backup.sh` creates a PostgreSQL dump plus runtime config/state. Backups contain
secrets and should be encrypted with `--passphrase-file`.

`restore.sh` is destructive and requires `--force`.

`upgrade.sh` consumes a release manifest, creates a pre-upgrade backup, updates
image references, runs migrations, and starts the stack.

`support-bundle.sh` creates sanitized diagnostics. Use `--redact-ips` before
sharing externally.

