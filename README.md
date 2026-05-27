# Lumen VPN public installer

Public installer/docs repository for Lumen VPN. This repo contains only deploy
templates, installer scripts, release metadata, and public operator docs.

It must not contain private backend/frontend/node-agent/protocol source,
registry tokens, license keys, SSH credentials, subscription URLs, generated
runtime configs, support bundles, or backups.

## Quick start

```bash
cp .env.example .env
$EDITOR .env
sudo ./scripts/install.sh --config .env --dry-run
```

Production installs require real domains, ACME email, registry access if needed,
and image references pinned by digest from a signed release manifest.

```bash
sudo ./scripts/install.sh --config /opt/lumen/.env
```

## Operations

```bash
sudo ./scripts/doctor.sh --config /opt/lumen/.env
sudo ./scripts/backup.sh --config /opt/lumen/.env --passphrase-file /root/lumen-backup.pass
sudo ./scripts/restore.sh --config /opt/lumen/.env --backup /secure/backup.tar.gz.enc --passphrase-file /root/lumen-backup.pass --force
sudo ./scripts/upgrade.sh --config /opt/lumen/.env --manifest release/manifest.template.json --dry-run
sudo ./scripts/support-bundle.sh --config /opt/lumen/.env --redact-ips
```

Manual node install is fallback only. The main product flow is push provisioning
from the private panel/backend over SSH, then outbound node-agent management.

```bash
sudo ./scripts/install-node.sh --panel-url https://panel.example.com --install-token-stdin
```

Free mode is represented by `FREE_NODE_LIMIT=3`. Licensed mode is a placeholder
until the private license service is connected.

## Local checks

```bash
shellcheck scripts/*.sh scripts/lib/*.sh
docker compose --env-file .env.example -f deploy/compose/lumen.yml config
docker compose --env-file .env.example -f deploy/compose/lumen-node.yml config
./scripts/secret-scan.sh .
```

