# Node install fallback

Manual node install is fallback only. The preferred flow is panel push
provisioning over SSH, with temporary SSH credentials wiped after bootstrap.

Fallback:

```bash
sudo ./scripts/install-node.sh --panel-url https://panel.example.com --install-token-stdin
```

The one-time token should be passed through stdin or a root-only file, not shell
history. The node-agent connects outbound to the panel; no inbound admin port is
opened by this scaffold.

