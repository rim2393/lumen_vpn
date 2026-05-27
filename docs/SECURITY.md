# Security

This public repo must not contain private source, registry tokens, passwords,
license keys, SSH credentials, subscription URLs, backups, support bundles, or
generated runtime configs.

Real passwords and generated `.env` values must never be committed, even for a
temporary smoke test. Use placeholders in docs and store secrets only in
root-only files on the target host.

Use file-based secret inputs:

- `REGISTRY_TOKEN_FILE`
- `LICENSE_KEY_FILE`
- `LUMEN_INSTALL_TOKEN_FILE`
- `TELEGRAM_BOT_TOKEN_FILE`
- `SMTP_PASSWORD_FILE`
- `GOOGLE_OAUTH_CLIENT_SECRET_FILE`

Do not pass node install tokens with a `LUMEN_INSTALL_TOKEN` environment
variable. The node installer writes the one-time token to a root-only file and
the node-agent receives only the file path.

The panel does not trust local license rows for paid capacity. Configure the
central license public key with `LUMEN_CENTRAL_LICENSE_PUBLIC_KEY_B64`; only
signed entitlements from that key can raise the node limit above the free tier.

Support bundles redact common secret keys by default and can redact IP addresses
with `--redact-ips`. Compose logs are passed through the same redactor before
they are added to the bundle.

The fallback node installer grants the node-agent Docker socket access and
network capabilities. Only install nodes you trust, rotate one-time install
tokens, and avoid colocating unrelated workloads on node hosts.
