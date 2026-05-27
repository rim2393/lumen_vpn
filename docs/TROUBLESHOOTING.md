# Troubleshooting

## Compose does not render

```bash
docker compose --env-file /opt/lumen/.env -f deploy/compose/lumen.yml config
```

Check missing env values and placeholder image digests.

## TLS fails

Verify DNS, ports 80/443, `ACME_EMAIL`, and Nginx acme challenge config.

## Private image pull fails

Set `REGISTRY_USERNAME` and put the token in `REGISTRY_TOKEN_FILE`. Do not put
tokens inline in `.env`.

