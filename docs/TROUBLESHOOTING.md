# Troubleshooting

## Compose does not render

```bash
docker compose --env-file /opt/lumen/.env -f deploy/compose/lumen.yml config
```

Check missing env values, duplicate loopback ports, and placeholder image
digests.

If the panel API container is healthy but Nginx cannot reach `/api/`, confirm
that `LUMEN_API_INTERNAL_PORT` matches the private API image listen port and
that `LUMEN_API_PORT` remains the local host port used by Nginx.

## TLS fails

Verify DNS, ports 80/443, `ACME_EMAIL`, `LUMEN_ACME_ENABLED`, and Nginx ACME
challenge config. The installer starts with a temporary self-signed certificate
and then replaces it with ACME output when issuance succeeds.

## Private image pull fails

Set `REGISTRY_USERNAME` and put the token in `REGISTRY_TOKEN_FILE`. Do not put
tokens inline in `.env`.

If private images are required, set `REGISTRY_REQUIRED=true`; this makes the
installer fail early when registry credentials are missing instead of waiting
for `docker compose pull`.

## Upgrade fails

Use the recorded state path from `LUMEN_LAST_UPGRADE_STATE`:

```bash
sudo ./scripts/rollback.sh --config /opt/lumen/.env --force
```

Use full backup rollback only when database/runtime state also needs to go back:

```bash
sudo ./scripts/rollback.sh --config /opt/lumen/.env --backup /path/to/backup.tar.gz.enc --passphrase-file /root/lumen-backup.pass --force
```

## Node fallback cannot pull image

Keep `REGISTRY_HOST`, `REGISTRY_USERNAME`, `REGISTRY_TOKEN_FILE`, and
`REGISTRY_REQUIRED` in `/opt/lumen-node/.env`. The node installer preserves
those fields when it rewrites non-secret node settings.
