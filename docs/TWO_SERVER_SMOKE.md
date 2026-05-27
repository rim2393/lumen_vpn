# Two-server smoke

Use this runbook to validate one panel VPS plus one node VPS before a broader
release. The inventory template below is intentionally secret-free.

Do not commit filled inventories, real passwords, one-time install tokens,
private keys, subscription URLs, generated `.env` files, support bundles, or
backups. The template may name secret file paths, but it must never contain the
secret values stored at those paths.

## Secret-free inventory template

Copy this block into a private operator note if needed. Keep sample IPs in the
reserved `203.0.113.0/24` range when documenting examples in this repo.

```yaml
smoke_id: smoke-YYYYMMDD-01
release_manifest: release/manifest.template.json
operator: <operator-name>

panel:
  provider_region: <provider-region>
  public_ip: 203.0.113.10
  ssh_host: panel-smoke.example.net
  ssh_user: ubuntu
  ssh_key_path: ~/.ssh/lumen-panel-smoke
  panel_domain: panel.example.com
  subscription_domain: sub.example.com
  acme_email: ops@example.com
  env_file: /opt/lumen/.env
  registry_token_file: /opt/lumen/secrets/registry-token

node:
  provider_region: <provider-region>
  public_ip: 203.0.113.20
  ssh_host: node-smoke.example.net
  ssh_user: ubuntu
  ssh_key_path: ~/.ssh/lumen-node-smoke
  node_name: smoke-node-01
  env_file: /opt/lumen-node/.env
  install_token_source: stdin-or-/root/lumen-node-install-token

checks:
  panel_health_url: https://panel.example.com/api/v1/health/live
  subscription_public_url: https://sub.example.com
```

## Secret-free local render

Run these checks from a clean public repo checkout before copying anything to
the VPS hosts. They do not require real domains, tokens, or generated secrets.

```bash
docker compose --env-file .env.example -f deploy/compose/lumen.yml config
docker compose --env-file .env.example -f deploy/compose/lumen-node.yml config
jq -e '.schema == "lumen.release.v1" and (.images | has("api") and has("web") and has("node_agent") and has("subscription"))' release/manifest.template.json
bash scripts/secret-scan.sh .
```

## Panel dry run

Run this before writing any production secrets. If `/tmp/lumen-panel.env` still
contains generated placeholders, dry-run logs the keys it would update, suppresses
the values, and leaves the file unchanged.

```bash
install -m 0600 .env.example /tmp/lumen-panel.env
$EDITOR /tmp/lumen-panel.env
sudo ./scripts/install.sh --config /tmp/lumen-panel.env --dry-run
docker compose --env-file /tmp/lumen-panel.env -f deploy/compose/lumen.yml config
```

For tag-only pre-release private images, set `LUMEN_ALLOW_UNPINNED_IMAGES=true`
in `/tmp/lumen-panel.env` or pass `--allow-unpinned-images`. Keep the override
out of production release configs.

## Panel install

Use a private config path on the panel VPS. Replace image digests with signed
release values first, then run the installer.

```bash
sudo install -m 0600 .env.example /opt/lumen/.env
sudo ./scripts/configure.sh --config /opt/lumen/.env --force
sudo ./scripts/install.sh --config /opt/lumen/.env --dry-run
sudo ./scripts/install.sh --config /opt/lumen/.env
sudo ./scripts/doctor.sh --config /opt/lumen/.env
```

Required live evidence before expanding beyond two servers:

- `docker compose --env-file /opt/lumen/.env -f deploy/compose/lumen.yml ps`
  shows `postgres`, `redis`, `api`, `web`, and `subscription` running.
- `curl -fsS https://panel.example.com/api/v1/health/live` returns success.
- `curl -fsS https://sub.example.com` returns the subscription front door.
- `sudo ./scripts/backup.sh --config /opt/lumen/.env --passphrase-file /root/lumen-backup.pass`
  creates an encrypted backup.
- `sudo ./scripts/support-bundle.sh --config /opt/lumen/.env --redact-ips`
  creates a sanitized support bundle.

## Node fallback smoke

The preferred node flow is panel push provisioning. Use manual fallback only
when testing the public installer path or when push provisioning is unavailable.

```bash
sudo ./scripts/install-node.sh \
  --control-plane-url https://panel.example.com \
  --node-name smoke-node-01 \
  --install-token-stdin \
  --dry-run
```

The node dry run does not read stdin even when `--install-token-stdin` is
present. To render the node compose file with the public template only, run:

```bash
docker compose --env-file .env.example -f deploy/compose/lumen-node.yml config
```

For a live fallback, pass the one-time token through stdin or a root-only file as
documented in `docs/NODE_INSTALL.md`. Remove the token file after bootstrap and
confirm the node-agent is visible from the panel.

## Upgrade and rollback smoke

Use a signed manifest produced by the private CI pipeline, not
`release/manifest.template.json`.

```bash
sudo ./scripts/upgrade.sh \
  --config /opt/lumen/.env \
  --manifest /secure/lumen-release.json \
  --backup-passphrase-file /root/lumen-backup.pass \
  --dry-run
sudo ./scripts/rollback.sh --config /opt/lumen/.env --force --dry-run
```
