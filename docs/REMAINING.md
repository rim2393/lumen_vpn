# Remaining

- Private images must keep the public installer contracts stable: `alembic
  upgrade head`, health checks, bootstrap admin env, and node-agent registration.
- Release manifests must be generated and signed by the private CI pipeline.
- End-to-end VPS install, ACME, backup, restore, upgrade, rollback, and
  support-bundle tests are still required.
- Typed `lumenctl` is not included in this Bash scaffold.
