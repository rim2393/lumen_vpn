#!/usr/bin/env bash
set -Eeuo pipefail

ALLOW_TEMPLATE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-template) ALLOW_TEMPLATE=1; shift ;;
    -h|--help) echo "Usage: validate-manifest.sh [--allow-template] MANIFEST"; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

MANIFEST_FILE="${1:-}"
[ -n "$MANIFEST_FILE" ] || { echo "manifest path is required" >&2; exit 2; }

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

if [ "$ALLOW_TEMPLATE" = "1" ]; then
  validate_release_manifest_template "$MANIFEST_FILE"
else
  validate_release_manifest "$MANIFEST_FILE"
fi

log "manifest valid: $MANIFEST_FILE"
