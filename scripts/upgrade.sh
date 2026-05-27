#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
MANIFEST_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --manifest) MANIFEST_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: upgrade.sh --manifest PATH [--config PATH] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

jq_get() {
  jq -r "$1" "$MANIFEST_FILE"
}

main() {
  require_root_or_dry_run
  [ -r "$MANIFEST_FILE" ] || die "--manifest is required"
  have_cmd jq || die "jq is required"
  jq -e '.schema == "lumen.release.v1"' "$MANIFEST_FILE" >/dev/null || die "unsupported manifest schema"
  load_env
  backup_args=(--config "$CONFIG_FILE" --allow-plaintext)
  if [ "$DRY_RUN" = "1" ]; then
    backup_args+=(--dry-run)
  fi
  "$REPO_ROOT/scripts/backup.sh" "${backup_args[@]}"
  env_set LUMEN_VERSION "$(jq_get '.version')"
  env_set LUMEN_API_IMAGE "$(jq_get '.images.api')"
  env_set LUMEN_WEB_IMAGE "$(jq_get '.images.web')"
  env_set LUMEN_NODE_AGENT_IMAGE "$(jq_get '.images.node_agent')"
  env_set LUMEN_SUBSCRIPTION_IMAGE "$(jq_get '.images.subscription')"
  env_set FREE_NODE_LIMIT "$(jq_get '.free_node_limit // 3')"
  load_env
  validate_images strict
  compose_run config >/dev/null
  compose_run pull
  compose_run run --rm api lumen-api migrate
  compose_run up -d
  log "upgrade complete"
}

main "$@"
