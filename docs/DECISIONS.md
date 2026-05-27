# Decisions

- Public repo scope is installer/docs/templates/release metadata only.
- Runtime secrets are generated on the target host.
- Production images must be pinned by digest.
- Pre-release smoke may use tag-only or placeholder image refs only with an
  explicit `LUMEN_ALLOW_UNPINNED_IMAGES` override.
- Free mode supports three active nodes through `FREE_NODE_LIMIT=3`.
- Push node provisioning lives in the private panel/backend; this repo provides
  only fallback node bootstrap.
- Upgrade backups require encryption by default. Plaintext upgrade backups need
  explicit `--allow-plaintext-backup` and are for isolated smoke runs only.
- Signed release manifests must be used for upgrade. The public template is
  valid only with `scripts/validate-manifest.sh --allow-template`.
