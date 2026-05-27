# Node install fallback

Manual node install is fallback only. The preferred flow is panel push
provisioning over SSH, with temporary SSH credentials wiped after bootstrap.

Use this script only when push provisioning is unavailable or when a two-server
smoke needs to exercise manual bootstrap. The node-agent connects outbound to the
control plane URL through `LUMEN_CONTROL_PLANE_URL`; no inbound admin port is
opened by this scaffold.

Do not commit real passwords, install tokens, generated node configs, SSH
private keys, or filled smoke inventories. Token values should be passed through
stdin or a root-only file, not shell history or environment variables. The
container receives only `LUMEN_INSTALL_TOKEN_FILE=/run/lumen-node/install-token`.

## Dry run

Dry-run validates arguments and shows the compose actions without reading,
printing, or writing the install token. It also logs the non-secret node env
fields that would be written to `/opt/lumen-node/.env`.

```bash
sudo ./scripts/install-node.sh \
  --control-plane-url https://panel.example.com \
  --node-name smoke-node-01 \
  --install-token-stdin \
  --dry-run
```

## Fallback install with stdin

```bash
sudo ./scripts/install-node.sh --control-plane-url https://panel.example.com --install-token-stdin
```

Paste the one-time token only when prompted by your shell session. Prefer a
private terminal session because terminal echo behavior depends on how stdin is
provided.

## Fallback install with a root-only token file

```bash
sudo install -m 0600 /dev/null /root/lumen-node-install-token
sudoedit /root/lumen-node-install-token
sudo ./scripts/install-node.sh \
  --control-plane-url https://panel.example.com \
  --node-name smoke-node-01 \
  --install-token-file /root/lumen-node-install-token
sudo rm -f /root/lumen-node-install-token
```

The generated node config lives at `/opt/lumen-node/.env` and should remain on
the node VPS only. It contains non-secret node settings such as
`LUMEN_CONTROL_PLANE_URL`, `LUMEN_NODE_NAME`, and `LUMEN_NODE_AGENT_IMAGE`.
Treat `/opt/lumen-node/secrets/install-token` as sensitive until the panel
confirms it has been consumed or rotated.

`--panel-url` remains accepted as a compatibility alias for
`--control-plane-url`, but new docs and automation should use the control-plane
name.
