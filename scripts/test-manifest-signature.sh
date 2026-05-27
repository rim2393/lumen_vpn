#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PRIVATE_KEY="$TMPDIR/release-signing.key"
PUBLIC_KEY="$TMPDIR/release-signing.pub"
UNSIGNED_MANIFEST="$TMPDIR/release.unsigned.json"
SIGNED_MANIFEST="$TMPDIR/release.signed.json"
TAMPERED_PAYLOAD="$TMPDIR/release.tampered-payload.json"
TAMPERED_SIGNATURE="$TMPDIR/release.tampered-signature.json"
PAYLOAD="$TMPDIR/payload.json"
SIGNATURE="$TMPDIR/signature.bin"

openssl genpkey -algorithm Ed25519 -out "$PRIVATE_KEY" >/dev/null 2>&1
openssl pkey -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" >/dev/null 2>&1

jq '
  .signature.alg = "Ed25519"
  | .signature.kid = "ci-test-ed25519"
  | .signature.value = ""
' "$REPO_ROOT/release/manifest.template.json" >"$UNSIGNED_MANIFEST"

jq -cS 'del(.signature)' "$UNSIGNED_MANIFEST" >"$PAYLOAD"
openssl pkeyutl -sign -inkey "$PRIVATE_KEY" -rawin -in "$PAYLOAD" -out "$SIGNATURE"
SIGNATURE_B64="$(base64 <"$SIGNATURE" | tr -d '\n')"
jq --arg signature "$SIGNATURE_B64" '.signature.value = $signature' "$UNSIGNED_MANIFEST" >"$SIGNED_MANIFEST"

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

echo "[manifest-signature] ok"
