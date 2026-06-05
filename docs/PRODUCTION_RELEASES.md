# Production releases

Production updates are delivered through the public installer repository, but
private product source remains in `rim2393/full-revna-like-projekt`.

The release pipeline invariants are checked by
`scripts/validate-release-pipeline-guard.sh` in CI. A failure in that guard is a
release blocker because signing, digest pinning, deploy secrets, or the
official upgrade path may have been weakened.

## Flow

1. A commit lands on `main` in the private product repository.
2. The private `Build release images` workflow builds and pushes pinned GHCR
   images tagged as `main-<commit-sha>`.
3. After image verification, the private workflow sends a
   `product-release-published` dispatch event to this installer repository.
4. This repository resolves image digests, generates `release/prod.json`, signs
   it with the release Ed25519 key from GitHub Secrets, derives the matching
   public verification key, validates the signature, and commits the manifest
   plus public key.
5. The deploy step uploads the signed manifest, public verification key and the
   current public installer bundle to the production panel server.
6. The server runs `scripts/upgrade.sh`, which verifies the manifest, creates an
   encrypted backup, records pre-upgrade state, pulls images, runs migrations,
   restarts Compose, and runs `scripts/doctor.sh`.

Manual stable releases still use explicit versions such as `v0.1.10`; the same
workflow can be started from the GitHub Actions UI with `workflow_dispatch`.

## Required GitHub Secrets

Private product repo `rim2393/full-revna-like-projekt`:

- `LUMEN_PUBLIC_REPO_TOKEN`: token allowed to call repository dispatch on
  `rim2393/lumen_vpn`.

Public installer repo `rim2393/lumen_vpn`:

- `LUMEN_GHCR_READ_USERNAME`: GHCR username.
- `LUMEN_GHCR_READ_TOKEN`: token with read access to private GHCR images.
- `LUMEN_RELEASE_SIGNING_KEY`: Ed25519 private key in PEM format.
- `LUMEN_RELEASE_SIGNING_KID`: release key id, for example
  `lumen-release-main`.
- `LUMEN_PROD_HOST`: production panel host.
- `LUMEN_PROD_SSH_PORT`: SSH port, usually `22`.
- `LUMEN_PROD_SSH_USER`: deploy user, currently `root`.
- `LUMEN_PROD_SSH_KEY`: SSH private key authorized on the production server.
- `LUMEN_UPGRADE_BACKUP_PASSPHRASE`: passphrase used by encrypted pre-upgrade
  backups.

Do not store registry tokens, SSH private keys, release signing private keys, or
backup passphrases in git.

## Runtime Files On The Panel Server

- `/opt/lumen/installer/lumen_vpn`: public installer bundle used by the official
  upgrade path.
- `/opt/lumen/.env`: private runtime config.
- `/opt/lumen/release-signing.pub`: trusted release verification key.
- `/opt/lumen/releases/prod.json`: last promoted signed release manifest.
- `/opt/lumen/secrets/registry-token`: GHCR pull token.
- `/opt/lumen/secrets/upgrade-backup.pass`: encrypted backup passphrase.
- `/opt/lumen/backups`: pre-upgrade backups and rollback state.

Rollback after a failed update:

```bash
sudo /root/lumen-installer/lumen_vpn/scripts/rollback.sh \
  --config /opt/lumen/.env \
  --force
```
