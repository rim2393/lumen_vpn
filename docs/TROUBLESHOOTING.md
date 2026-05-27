# Troubleshooting

## Compose does not render

```bash
docker compose --env-file /opt/lumen/.env -f deploy/compose/lumen.yml config
```

Check missing env values and placeholder image digests.

If the panel API container is healthy but Nginx cannot reach `/api/`, confirm
that `LUMEN_API_INTERNAL_PORT` matches the private API image listen port and
that `LUMEN_API_PORT` remains the local host port used by Nginx.

## TLS fails

Verify DNS, ports 80/443, `ACME_EMAIL`, and Nginx acme challenge config.

## Private image pull fails

Set `REGISTRY_USERNAME` and put the token in `REGISTRY_TOKEN_FILE`. Do not put
tokens inline in `.env`.
