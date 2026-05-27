#!/usr/bin/env bash
set -Eeuo pipefail

MANIFEST_FILE=""
PRIVATE_KEY_FILE=""
OUTPUT_FILE=""
KID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --private-key-file) PRIVATE_KEY_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --kid) KID="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sign-manifest.sh --private-key-file PATH --kid KEY_ID --output PATH MANIFEST"
      exit 0
      ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) MANIFEST_FILE="$1"; shift ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

[ -n "$MANIFEST_FILE" ] || die "manifest path is required"
[ -n "$PRIVATE_KEY_FILE" ] || die "--private-key-file is required"
[ -n "$OUTPUT_FILE" ] || die "--output is required"
[ -n "$KID" ] || die "--kid is required"
[ -r "$MANIFEST_FILE" ] || die "manifest is not readable: $MANIFEST_FILE"
[ -r "$PRIVATE_KEY_FILE" ] || die "private key file is not readable"
have_cmd jq || die "jq is required"
have_cmd openssl || die "openssl is required"

validate_release_manifest_template "$MANIFEST_FILE"
openssl pkey -in "$PRIVATE_KEY_FILE" -noout >/dev/null 2>&1 || die "private key file is not a valid key"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

UNSIGNED_MANIFEST="$TMPDIR/release.unsigned.json"
PAYLOAD="$TMPDIR/payload.json"
SIGNATURE="$TMPDIR/signature.bin"

jq --arg kid "$KID" '
  .signature.alg = "Ed25519"
  | .signature.kid = $kid
  | .signature.value = ""
' "$MANIFEST_FILE" >"$UNSIGNED_MANIFEST"

jq -cS 'del(.signature)' "$UNSIGNED_MANIFEST" >"$PAYLOAD"
openssl pkeyutl -sign -inkey "$PRIVATE_KEY_FILE" -rawin -in "$PAYLOAD" -out "$SIGNATURE"
SIGNATURE_B64="$(base64 <"$SIGNATURE" | tr -d '\n')"

mkdir -p "$(dirname "$OUTPUT_FILE")"
jq --arg signature "$SIGNATURE_B64" '.signature.value = $signature' "$UNSIGNED_MANIFEST" >"$OUTPUT_FILE"
chmod 0644 "$OUTPUT_FILE"
log "signed release manifest written to $OUTPUT_FILE"
