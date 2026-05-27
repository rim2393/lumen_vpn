# Status

First public installer/docs scaffold exists. It is intended for static checks and
dry-run review. Real production install still needs private images, signed
release manifests, and registry access.

2026-05-27 two-server smoke:

- SSH access worked for the panel-designated VPS and node-designated VPS.
- Panel VPS reports Ubuntu 26.04, amd64; node VPS reports Ubuntu 24.04, amd64.
- Public installer tar uploaded to `/tmp`, panel dry-run completed, and node
  fallback dry-run completed.
- No real install was executed. Docker and Nginx were not installed on the
  smoke hosts yet, so live Compose pull/up and TLS checks remain pending.
