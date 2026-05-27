# Lumen VPN public installer

Public installer/docs repository for Lumen VPN. This repo contains only deploy
templates, installer scripts, release metadata, and public operator docs.

It must not contain private backend/frontend/node-agent/protocol source,
registry tokens, license keys, SSH credentials, subscription URLs, generated
runtime configs, support bundles, or backups.

See [Release Boundary](docs/RELEASE_BOUNDARY.md) for the enforced public/private
split.

Real passwords, one-time install tokens, and generated `.env` values must not
be committed. Keep smoke-test inventory notes secret-free and store credentials
only in root-only files on the target hosts.

## Quick start

```bash
sudo ./scripts/configure.sh --config /opt/lumen/.env
sudo ./scripts/install.sh --config /opt/lumen/.env --dry-run
```

Production installs require real domains, ACME email, registry access if needed,
and image references pinned by digest from a signed release manifest.
Pre-release smoke runs may set `LUMEN_ALLOW_UNPINNED_IMAGES=true` or pass
`--allow-unpinned-images`; do not use that override for production releases.
Production manifest validation also requires the Ed25519 public key file
configured in `LUMEN_RELEASE_PUBLIC_KEY_FILE`.

```bash
sudo ./scripts/install.sh --config /opt/lumen/.env
```

For a panel VPS plus node VPS smoke test, use the secret-free inventory template
and runbook in `docs/TWO_SERVER_SMOKE.md`.

## Operations

```bash
sudo ./scripts/doctor.sh --config /opt/lumen/.env
sudo ./scripts/backup.sh --config /opt/lumen/.env --passphrase-file /root/lumen-backup.pass
sudo ./scripts/restore.sh --config /opt/lumen/.env --backup /secure/backup.tar.gz.enc --passphrase-file /root/lumen-backup.pass --force
sudo ./scripts/upgrade.sh --config /opt/lumen/.env --manifest /secure/lumen-release.json --backup-passphrase-file /root/lumen-backup.pass --dry-run
sudo ./scripts/rollback.sh --config /opt/lumen/.env --state-dir /opt/lumen/backups/upgrade-state/<timestamp> --force
sudo ./scripts/support-bundle.sh --config /opt/lumen/.env --redact-ips
```

Manual node install is fallback only. The main product flow is push provisioning
from the private panel/backend over SSH, then outbound node-agent management.
See `docs/NODE_INSTALL.md` for fallback dry-run and token handling details.

```bash
sudo ./scripts/install-node.sh --control-plane-url https://panel.example.com --install-token-stdin
```

Free mode is represented by `FREE_NODE_LIMIT=3`. Licensed mode is connected by
the private control plane and central license service; this public repo only
stores installer fields and docs. Paid capacity is accepted by the panel only
from central signed entitlements verified with `LUMEN_CENTRAL_LICENSE_PUBLIC_KEY_B64`.

## Local checks

```bash
for f in scripts/*.sh scripts/lib/*.sh; do bash -n "$f"; done
shellcheck scripts/*.sh scripts/lib/*.sh
docker compose --env-file .env.example -f deploy/compose/lumen.yml config
docker compose --env-file .env.example -f deploy/compose/lumen-node.yml config
./scripts/validate-manifest.sh --allow-template release/manifest.template.json
./scripts/test-manifest-signature.sh
./scripts/secret-scan.sh .
```
