#!/usr/bin/env bash
set -Eeuo pipefail

CONTROL_PLANE_URL=""
TOKEN_FILE=""
TOKEN_STDIN=0
NODE_NAME="manual-node"
CONFIG_FILE="/opt/lumen-node/.env"
NODE_AGENT_IMAGE=""
ALLOW_UNPINNED_IMAGES=0
INSECURE_TLS=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --control-plane-url|--panel-url) CONTROL_PLANE_URL="$2"; shift 2 ;;
    --install-token-file) TOKEN_FILE="$2"; shift 2 ;;
    --install-token-stdin) TOKEN_STDIN=1; shift ;;
    --node-name) NODE_NAME="$2"; shift 2 ;;
    --node-agent-image) NODE_AGENT_IMAGE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --allow-unpinned-images) ALLOW_UNPINNED_IMAGES=1; shift ;;
    --insecure-tls) INSECURE_TLS=1; shift ;;
    -h|--help) echo "Usage: install-node.sh --control-plane-url URL (--install-token-stdin|--install-token-file PATH) [--node-name NAME] [--node-agent-image IMAGE] [--insecure-tls] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

install_node_packages() {
  if have_cmd apt-get; then
    run apt-get update
    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl jq docker.io docker-compose-v2
    elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl jq docker.io docker-compose-plugin
    else
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl jq docker.io docker-compose
    fi
    run systemctl enable --now docker
  else
    warn "apt-get not found; install Docker and Docker Compose v2 manually"
  fi
}

load_existing_node_env() {
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    set -a && source "$CONFIG_FILE" && set +a
  fi
}

write_node_env() {
  run mkdir -p "$(dirname "$CONFIG_FILE")"
  {
    printf 'TZ=%s\n' "${TZ:-UTC}"
    printf 'LUMEN_CONTROL_PLANE_URL=%s\n' "$CONTROL_PLANE_URL"
    printf 'LUMEN_NODE_NAME=%s\n' "$NODE_NAME"
    printf 'LUMEN_NODE_AGENT_IMAGE=%s\n' "$LUMEN_NODE_AGENT_IMAGE"
    printf 'LUMEN_NODE_STATE_DIR=%s\n' "$LUMEN_NODE_STATE_DIR"
    printf 'LUMEN_NODE_SECRETS_DIR=%s\n' "$LUMEN_NODE_SECRETS_DIR"
    printf 'LUMEN_ALLOW_UNPINNED_IMAGES=%s\n' "${LUMEN_ALLOW_UNPINNED_IMAGES:-false}"
    printf 'LUMEN_SKIP_IMAGE_PULL=%s\n' "${LUMEN_SKIP_IMAGE_PULL:-false}"
    printf 'LUMEN_DRY_RUN=%s\n' "${LUMEN_DRY_RUN:-false}"
    printf 'LUMEN_ENABLE_LIVE_SMOKE=%s\n' "${LUMEN_ENABLE_LIVE_SMOKE:-false}"
    printf 'LUMEN_XRAY_CONFIG_FILE=%s\n' "${LUMEN_XRAY_CONFIG_FILE:-/var/lib/lumen-node/runtime/xray/config.json}"
    printf 'LUMEN_XRAY_LOG_FILE=%s\n' "${LUMEN_XRAY_LOG_FILE:-/var/lib/lumen-node/runtime/xray/xray.log}"
    printf 'LUMEN_XRAY_RELOAD_MODE=%s\n' "${LUMEN_XRAY_RELOAD_MODE:-process}"
    printf 'LUMEN_HYSTERIA2_CONFIG_FILE=%s\n' "${LUMEN_HYSTERIA2_CONFIG_FILE:-/var/lib/lumen-node/runtime/hysteria2/config.json}"
    printf 'LUMEN_HYSTERIA2_LOG_FILE=%s\n' "${LUMEN_HYSTERIA2_LOG_FILE:-/var/lib/lumen-node/runtime/hysteria2/sing-box.log}"
    printf 'LUMEN_HYSTERIA2_PID_FILE=%s\n' "${LUMEN_HYSTERIA2_PID_FILE:-/var/lib/lumen-node/runtime/hysteria2/sing-box.pid}"
    printf 'LUMEN_HYSTERIA2_RELOAD_MODE=%s\n' "${LUMEN_HYSTERIA2_RELOAD_MODE:-process}"
    printf 'LUMEN_SHADOWSOCKS_CONFIG_FILE=%s\n' "${LUMEN_SHADOWSOCKS_CONFIG_FILE:-/var/lib/lumen-node/runtime/shadowsocks/config.json}"
    printf 'LUMEN_SHADOWSOCKS_LOG_FILE=%s\n' "${LUMEN_SHADOWSOCKS_LOG_FILE:-/var/lib/lumen-node/runtime/shadowsocks/sing-box.log}"
    printf 'LUMEN_SHADOWSOCKS_PID_FILE=%s\n' "${LUMEN_SHADOWSOCKS_PID_FILE:-/var/lib/lumen-node/runtime/shadowsocks/sing-box.pid}"
    printf 'LUMEN_SHADOWSOCKS_RELOAD_MODE=%s\n' "${LUMEN_SHADOWSOCKS_RELOAD_MODE:-process}"
    printf 'LUMEN_TUIC_CONFIG_FILE=%s\n' "${LUMEN_TUIC_CONFIG_FILE:-/var/lib/lumen-node/runtime/tuic/config.json}"
    printf 'LUMEN_TUIC_LOG_FILE=%s\n' "${LUMEN_TUIC_LOG_FILE:-/var/lib/lumen-node/runtime/tuic/sing-box.log}"
    printf 'LUMEN_TUIC_PID_FILE=%s\n' "${LUMEN_TUIC_PID_FILE:-/var/lib/lumen-node/runtime/tuic/sing-box.pid}"
    printf 'LUMEN_TUIC_RELOAD_MODE=%s\n' "${LUMEN_TUIC_RELOAD_MODE:-process}"
    printf 'LUMEN_WIREGUARD_CONFIG_FILE=%s\n' "${LUMEN_WIREGUARD_CONFIG_FILE:-/var/lib/lumen-node/runtime/wireguard/lumen-wg.conf}"
    printf 'LUMEN_WIREGUARD_RELOAD_MODE=%s\n' "${LUMEN_WIREGUARD_RELOAD_MODE:-wg-quick}"
    printf 'REGISTRY_HOST=%s\n' "${REGISTRY_HOST:-}"
    printf 'REGISTRY_USERNAME=%s\n' "${REGISTRY_USERNAME:-}"
    printf 'REGISTRY_TOKEN_FILE=%s\n' "${REGISTRY_TOKEN_FILE:-}"
    printf 'REGISTRY_REQUIRED=%s\n' "${REGISTRY_REQUIRED:-false}"
    if [ "$INSECURE_TLS" = "1" ]; then
      printf 'NODE_TLS_REJECT_UNAUTHORIZED=0\n'
    fi
  } >"$CONFIG_FILE"
  chmod 0600 "$CONFIG_FILE"
}

main() {
  require_root_or_dry_run
  [ -z "${LUMEN_INSTALL_TOKEN:-}" ] || die "LUMEN_INSTALL_TOKEN env is not supported; use --install-token-stdin or --install-token-file"
  load_existing_node_env
  [ -z "${LUMEN_INSTALL_TOKEN:-}" ] || die "LUMEN_INSTALL_TOKEN env is not supported; use --install-token-stdin or --install-token-file"
  CONTROL_PLANE_URL="${CONTROL_PLANE_URL:-${LUMEN_CONTROL_PLANE_URL:-${LUMEN_PANEL_URL:-}}}"
  if [ "$NODE_NAME" = "manual-node" ] && [ -n "${LUMEN_NODE_NAME:-}" ]; then
    NODE_NAME="$LUMEN_NODE_NAME"
  fi
  LUMEN_NODE_AGENT_IMAGE="${NODE_AGENT_IMAGE:-${LUMEN_NODE_AGENT_IMAGE:-ghcr.io/rim2393/lumen-node-agent:v0.1.9@sha256:918732068399e220dbfc82232d9e1c3528bb9e974eb827c43f0cd5d4c211745f}}"
  LUMEN_NODE_STATE_DIR="${LUMEN_NODE_STATE_DIR:-/opt/lumen-node/state}"
  LUMEN_NODE_SECRETS_DIR="${LUMEN_NODE_SECRETS_DIR:-/opt/lumen-node/secrets}"
  if [ "$ALLOW_UNPINNED_IMAGES" = "1" ]; then
    LUMEN_ALLOW_UNPINNED_IMAGES=true
  fi
  if [ "$INSECURE_TLS" = "1" ]; then
    warn "--insecure-tls disables Node.js TLS certificate verification for node-agent smoke testing"
  fi
  [ -n "$CONTROL_PLANE_URL" ] || die "--control-plane-url is required"
  printf '%s' "$CONTROL_PLANE_URL" | grep -Eq '^https://' || die "--control-plane-url must use https"
  LUMEN_CONTROL_PLANE_URL="$CONTROL_PLANE_URL"
  validate_node_config
  [ "$TOKEN_STDIN" = "1" ] || [ -n "$TOKEN_FILE" ] || die "install token source is required"
  validate_image_refs strict LUMEN_NODE_AGENT_IMAGE
  install_node_packages
  registry_login
  run mkdir -p "$LUMEN_NODE_SECRETS_DIR" "$LUMEN_NODE_STATE_DIR"
  run chown 1000:1000 "$LUMEN_NODE_SECRETS_DIR" "$LUMEN_NODE_STATE_DIR"
  run chmod 0700 "$LUMEN_NODE_SECRETS_DIR" "$LUMEN_NODE_STATE_DIR"
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would create $CONFIG_FILE with non-secret node settings"
    log "dry-run node env: LUMEN_CONTROL_PLANE_URL=$CONTROL_PLANE_URL LUMEN_NODE_NAME=$NODE_NAME"
    log "dry-run does not read, print, or write the install token"
  else
    write_node_env
    if [ "$TOKEN_STDIN" = "1" ]; then
      IFS= read -r token
      [ -n "$token" ] || die "empty install token"
      ( umask 077 && printf '%s\n' "$token" > "$LUMEN_NODE_SECRETS_DIR/install-token" )
    else
      [ -r "$TOKEN_FILE" ] || die "install token file is not readable"
      source_token_path="$(readlink -f "$TOKEN_FILE")"
      target_token_path="$(readlink -f "$LUMEN_NODE_SECRETS_DIR/install-token" 2>/dev/null || printf '%s' "$LUMEN_NODE_SECRETS_DIR/install-token")"
      if [ "$source_token_path" != "$target_token_path" ]; then
        install -m 0600 "$TOKEN_FILE" "$LUMEN_NODE_SECRETS_DIR/install-token"
      fi
    fi
    chown 1000:1000 "$LUMEN_NODE_SECRETS_DIR/install-token"
    chmod 0400 "$LUMEN_NODE_SECRETS_DIR/install-token"
  fi
  COMPOSE_FILE="$REPO_ROOT/deploy/compose/lumen-node.yml"
  compose_run config >/dev/null
  compose_pull
  compose_run up -d
  log "node-agent bootstrap started"
}

main "$@"
