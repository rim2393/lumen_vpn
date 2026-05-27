# Decisions

- Public repo scope is installer/docs/templates/release metadata only.
- Runtime secrets are generated on the target host.
- Production images must be pinned by digest.
- Free mode supports three active nodes through `FREE_NODE_LIMIT=3`.
- Push node provisioning lives in the private panel/backend; this repo provides
  only fallback node bootstrap.

