#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PRIVATE_KEY="$TMPDIR/release-signing.key"
PUBLIC_KEY="$TMPDIR/release-signing.pub"
SIGNED_MANIFEST="$TMPDIR/release.signed.json"
TAMPERED_PAYLOAD="$TMPDIR/release.tampered-payload.json"
TAMPERED_SIGNATURE="$TMPDIR/release.tampered-signature.json"
FUTURE_TEMPLATE="$TMPDIR/release.future-template.json"

openssl genpkey -algorithm Ed25519 -out "$PRIVATE_KEY" >/dev/null 2>&1
openssl pkey -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" >/dev/null 2>&1

bash "$REPO_ROOT/scripts/sign-manifest.sh" \
  --private-key-file "$PRIVATE_KEY" \
  --kid ci-test-ed25519 \
  --output "$SIGNED_MANIFEST" \
  "$REPO_ROOT/release/manifest.template.json" >/dev/null

bash "$REPO_ROOT/scripts/validate-manifest.sh" --public-key-file "$PUBLIC_KEY" "$SIGNED_MANIFEST" >/dev/null

jq '.free_node_limit = 4' "$SIGNED_MANIFEST" >"$TAMPERED_PAYLOAD"
if bash "$REPO_ROOT/scripts/validate-manifest.sh" --public-key-file "$PUBLIC_KEY" "$TAMPERED_PAYLOAD" >/dev/null 2>&1; then
  echo "tampered manifest payload passed signature validation" >&2
  exit 1
fi

BAD_SIGNATURE_B64="$(dd if=/dev/zero bs=64 count=1 2>/dev/null | base64 | tr -d '\n')"
jq --arg signature "$BAD_SIGNATURE_B64" '.signature.value = $signature' "$SIGNED_MANIFEST" >"$TAMPERED_SIGNATURE"
if bash "$REPO_ROOT/scripts/validate-manifest.sh" --public-key-file "$PUBLIC_KEY" "$TAMPERED_SIGNATURE" >/dev/null 2>&1; then
  echo "tampered manifest signature passed validation" >&2
  exit 1
fi

jq '.installer_min_version = "v99.0.0"' "$REPO_ROOT/release/manifest.template.json" >"$FUTURE_TEMPLATE"
if bash "$REPO_ROOT/scripts/validate-manifest.sh" --allow-template "$FUTURE_TEMPLATE" >/dev/null 2>&1; then
  echo "future installer_min_version passed validation" >&2
  exit 1
fi

echo "[manifest-signature] ok"
