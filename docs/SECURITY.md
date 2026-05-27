# Security

This public repo must not contain private source, registry tokens, passwords,
license keys, SSH credentials, subscription URLs, backups, support bundles, or
generated runtime configs.

Use file-based secret inputs:

- `REGISTRY_TOKEN_FILE`
- `LICENSE_KEY_FILE`
- `TELEGRAM_BOT_TOKEN_FILE`
- `SMTP_PASSWORD_FILE`
- `GOOGLE_OAUTH_CLIENT_SECRET_FILE`

Support bundles redact common secret keys by default and can redact IP addresses
with `--redact-ips`.

