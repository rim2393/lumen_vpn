#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_URL=""
TOKEN_FILE=""
TOKEN_STDIN=0
NODE_NAME="manual-node"
CONFIG_FILE="/opt/lumen-node/.env"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --panel-url) PANEL_URL="$2"; shift 2 ;;
    --install-token-file) TOKEN_FILE="$2"; shift 2 ;;
    --install-token-stdin) TOKEN_STDIN=1; shift ;;
    --node-name) NODE_NAME="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: install-node.sh --panel-url URL (--install-token-stdin|--install-token-file PATH)"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

write_node_env() {
  {
    printf 'TZ=%s\n' "${TZ:-UTC}"
    printf 'LUMEN_PANEL_URL=%s\n' "$PANEL_URL"
    printf 'LUMEN_NODE_NAME=%s\n' "$NODE_NAME"
    printf 'LUMEN_NODE_AGENT_IMAGE=%s\n' "${LUMEN_NODE_AGENT_IMAGE:-ghcr.io/rim2393/lumen-node-agent:v0.1.0@sha256:0000000000000000000000000000000000000000000000000000000000000000}"
  } >"$CONFIG_FILE"
  chmod 0600 "$CONFIG_FILE"
}

main() {
  require_root_or_dry_run
  [ -n "$PANEL_URL" ] || die "--panel-url is required"
  printf '%s' "$PANEL_URL" | grep -Eq '^https://' || die "--panel-url must use https"
  [ "$TOKEN_STDIN" = "1" ] || [ -n "$TOKEN_FILE" ] || die "install token source is required"
  run mkdir -p /opt/lumen-node/secrets /opt/lumen-node/state
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would create $CONFIG_FILE with non-secret node settings"
    log "dry-run node env: LUMEN_PANEL_URL=$PANEL_URL LUMEN_NODE_NAME=$NODE_NAME"
    log "dry-run does not read, print, or write the install token"
  else
    write_node_env
    if [ "$TOKEN_STDIN" = "1" ]; then
      IFS= read -r token
      printf '%s\n' "$token" > /opt/lumen-node/secrets/install-token
    else
      install -m 0600 "$TOKEN_FILE" /opt/lumen-node/secrets/install-token
    fi
  fi
  COMPOSE_FILE="$REPO_ROOT/deploy/compose/lumen-node.yml"
  compose_run config >/dev/null
  compose_run pull
  compose_run up -d
  log "node-agent bootstrap started"
}

main "$@"
