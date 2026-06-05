#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH_WORKFLOW="$ROOT_DIR/.github/workflows/publish-prod-release.yml"
CI_WORKFLOW="$ROOT_DIR/.github/workflows/ci.yml"
PRODUCTION_DOC="$ROOT_DIR/docs/PRODUCTION_RELEASES.md"
OPERATIONS_DOC="$ROOT_DIR/docs/OPERATIONS.md"

fail() {
  printf '[release-pipeline-guard][error] %s\n' "$*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing required file: ${1#"$ROOT_DIR"/}"
}

require_text() {
  local file="$1" needle="$2"
  grep -Fq "$needle" "$file" || fail "${file#"$ROOT_DIR"/} missing required text: $needle"
}

for file in "$PUBLISH_WORKFLOW" "$CI_WORKFLOW" "$PRODUCTION_DOC" "$OPERATIONS_DOC"; do
  require_file "$file"
done

for secret in \
  LUMEN_GHCR_READ_USERNAME \
  LUMEN_GHCR_READ_TOKEN \
  LUMEN_RELEASE_SIGNING_KEY \
  LUMEN_RELEASE_SIGNING_KID \
  LUMEN_PROD_HOST \
  LUMEN_PROD_SSH_USER \
  LUMEN_PROD_SSH_KEY \
  LUMEN_UPGRADE_BACKUP_PASSPHRASE
do
  require_text "$PUBLISH_WORKFLOW" "$secret"
done

require_text "$PUBLISH_WORKFLOW" "LUMEN_RELEASE_SIGNING_KEY secret is required"
require_text "$PUBLISH_WORKFLOW" "openssl pkey -in \"\${signing_key_file}\" -pubout -out \"\${public_key_file}\""
require_text "$PUBLISH_WORKFLOW" "bash ./scripts/sign-manifest.sh"
require_text "$PUBLISH_WORKFLOW" "bash ./scripts/validate-manifest.sh"
require_text "$PUBLISH_WORKFLOW" "install -m 0644 \"\${signed_manifest}\" ./release/prod.json"
require_text "$PUBLISH_WORKFLOW" "install -m 0644 \"\${public_key_file}\" ./release/release-signing.pub"
require_text "$PUBLISH_WORKFLOW" "bash ./scripts/upgrade.sh"
require_text "$PUBLISH_WORKFLOW" "bash ./scripts/doctor.sh"
require_text "$PUBLISH_WORKFLOW" "REGISTRY_REQUIRED true"
require_text "$PUBLISH_WORKFLOW" "release/prod.json release/release-signing.pub"

if grep -Eiq 'skip(ping)? .*sign|skip(ping)? .*manifest|continue-on-error:\s*true' "$PUBLISH_WORKFLOW"; then
  fail "publish workflow must not silently skip signing/manifest/deploy failures"
fi

require_text "$CI_WORKFLOW" "Validate release pipeline guard"
require_text "$CI_WORKFLOW" "bash ./scripts/validate-release-pipeline-guard.sh"

require_text "$PRODUCTION_DOC" "LUMEN_RELEASE_SIGNING_KEY"
require_text "$PRODUCTION_DOC" "LUMEN_PUBLIC_REPO_TOKEN"
require_text "$PRODUCTION_DOC" "signed release manifest"
require_text "$OPERATIONS_DOC" "publish-prod-release.yml"
require_text "$OPERATIONS_DOC" "signs"
require_text "$OPERATIONS_DOC" "upgrade.sh"

printf '[release-pipeline-guard] ok\n'
