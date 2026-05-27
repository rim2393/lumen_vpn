#!/usr/bin/env bash
set -Eeuo pipefail

VERSION=""
OUTPUT_FILE=""
RELEASED_AT=""
INSTALLER_MIN_VERSION="${INSTALLER_MIN_VERSION:-v0.1.9}"
FREE_NODE_LIMIT="${FREE_NODE_LIMIT:-3}"

API_IMAGE_REPO="${LUMEN_API_IMAGE_REPO:-ghcr.io/rim2393/lumen-api}"
WEB_IMAGE_REPO="${LUMEN_WEB_IMAGE_REPO:-ghcr.io/rim2393/lumen-web}"
NODE_AGENT_IMAGE_REPO="${LUMEN_NODE_AGENT_IMAGE_REPO:-ghcr.io/rim2393/lumen-node-agent}"
SUBSCRIPTION_IMAGE_REPO="${LUMEN_SUBSCRIPTION_IMAGE_REPO:-ghcr.io/rim2393/lumen-subscription-page}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --released-at) RELEASED_AT="$2"; shift 2 ;;
    --installer-min-version) INSTALLER_MIN_VERSION="$2"; shift 2 ;;
    --free-node-limit) FREE_NODE_LIMIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: generate-release-manifest.sh --version TAG --output PATH [--released-at ISO8601] [--installer-min-version vX.Y.Z] [--free-node-limit N]"
      exit 0
      ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) echo "Unexpected argument: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[lumen-release] %s\n' "$*" >&2; }
warn() { printf '[lumen-release][warn] %s\n' "$*" >&2; }
die() { printf '[lumen-release][error] %s\n' "$*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

resolve_pinned_image() {
  local repo="$1" tag="$2" ref inspect digest manifest_json
  ref="$repo:$tag"
  log "resolving $ref"
  if ! inspect="$(docker buildx imagetools inspect "$ref" 2>&1)"; then
    warn "docker buildx imagetools inspect failed for $ref; trying docker manifest inspect"
    if ! manifest_json="$(docker manifest inspect --verbose "$ref" 2>&1)"; then
      printf '%s\n' "$inspect" >&2
      printf '%s\n' "$manifest_json" >&2
      die "failed to inspect image: $ref"
    fi
    digest="$(printf '%s\n' "$manifest_json" | jq -r '.Descriptor.digest // empty')"
    [ -n "$digest" ] || die "image digest not found for $ref"
    printf '%s@%s' "$ref" "$digest"
    return 0
  fi
  digest="$(printf '%s\n' "$inspect" | awk '/^Digest:/ { print $2; exit }')"
  [ -n "$digest" ] || die "image digest not found for $ref"
  printf '%s@%s' "$ref" "$digest"
}

[ -n "$VERSION" ] || die "--version is required"
[ -n "$OUTPUT_FILE" ] || die "--output is required"
printf '%s' "$VERSION" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$' || die "invalid release version tag: $VERSION"
printf '%s' "$FREE_NODE_LIMIT" | grep -Eq '^[0-9]+$' || die "--free-node-limit must be numeric"
have_cmd docker || die "docker is required"
have_cmd jq || die "jq is required"

RELEASED_AT="${RELEASED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

api_image="$(resolve_pinned_image "$API_IMAGE_REPO" "$VERSION")"
web_image="$(resolve_pinned_image "$WEB_IMAGE_REPO" "$VERSION")"
node_agent_image="$(resolve_pinned_image "$NODE_AGENT_IMAGE_REPO" "$VERSION")"
subscription_image="$(resolve_pinned_image "$SUBSCRIPTION_IMAGE_REPO" "$VERSION")"

mkdir -p "$(dirname "$OUTPUT_FILE")"
jq -n \
  --arg version "$VERSION" \
  --arg released_at "$RELEASED_AT" \
  --arg installer_min_version "$INSTALLER_MIN_VERSION" \
  --arg api_image "$api_image" \
  --arg web_image "$web_image" \
  --arg node_agent_image "$node_agent_image" \
  --arg subscription_image "$subscription_image" \
  --argjson free_node_limit "$FREE_NODE_LIMIT" \
  '{
    schema: "lumen.release.v1",
    version: $version,
    released_at: $released_at,
    installer_min_version: $installer_min_version,
    free_node_limit: $free_node_limit,
    images: {
      api: $api_image,
      web: $web_image,
      node_agent: $node_agent_image,
      subscription: $subscription_image
    },
    signature: {
      alg: "Ed25519",
      kid: "release-signing-key-id",
      value: "BASE64_SIGNATURE_PLACEHOLDER"
    }
  }' >"$OUTPUT_FILE"
chmod 0644 "$OUTPUT_FILE"
log "release manifest template written to $OUTPUT_FILE"
