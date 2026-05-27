# Status

First public installer/docs scaffold exists. It is intended for static checks and
dry-run review. Real production install still needs private images, signed
release manifests, and registry access.

The public installer now includes config bootstrap, domain/port validation,
ACME certificate issuance path, encrypted backup expectation for upgrades,
pre-upgrade state recording, rollback, support-bundle redaction, and node
fallback bootstrap docs.

2026-05-27 two-server smoke:

- SSH access worked for the panel-designated VPS and node-designated VPS.
- Panel VPS reports Ubuntu 26.04, amd64; node VPS reports Ubuntu 24.04, amd64.
- Public installer tar uploaded to `/tmp`, panel dry-run completed, and node
  fallback dry-run completed.
- No real install was executed in this public-repo pass. Docker and Nginx were
  not installed on the smoke hosts yet, so live Compose pull/up, ACME, health,
  and node registration checks remain pending.
