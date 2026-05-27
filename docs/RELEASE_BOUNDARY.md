# Release Boundary

This repository is safe to publish because it contains only public delivery
assets:

- installer and operations scripts under `scripts/`
- Docker Compose and Nginx templates under `deploy/`
- public operator documentation under `docs/`
- release manifest templates under `release/`
- CI checks for installer, manifest, secret, and boundary validation

It must not contain private product source code. The private source and build
pipelines remain in the closed repositories that produce pinned container
images:

- self-hosted control plane, API, web UI, node-agent, subscription rendering,
  protocol registry, and edge components
- central license server and commercial portal
- future Android and Windows client source

Public installers consume only signed release metadata and pinned image
references. Runtime secrets are generated or supplied on the target host and
must stay outside this repository.

Run the boundary check before publishing:

```bash
bash ./scripts/check-public-boundary.sh .
```
