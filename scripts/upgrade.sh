#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
MANIFEST_FILE=""
BACKUP_PASSPHRASE_FILE="${UPGRADE_BACKUP_PASSPHRASE_FILE:-}"
ALLOW_PLAINTEXT_BACKUP=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --manifest) MANIFEST_FILE="$2"; shift 2 ;;
    --backup-passphrase-file) BACKUP_PASSPHRASE_FILE="$2"; shift 2 ;;
    --allow-plaintext-backup) ALLOW_PLAINTEXT_BACKUP=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: upgrade.sh --manifest PATH [--config PATH] [--backup-passphrase-file PATH|--allow-plaintext-backup] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

jq_get() {
  jq -r "$1" "$MANIFEST_FILE"
}

record_upgrade_state() {
  local ts state_dir
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  state_dir="$LUMEN_BACKUP_DIR/upgrade-state/$ts"
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would record pre-upgrade state at $state_dir"
  else
    mkdir -p "$state_dir"
    install -m 0600 "$CONFIG_FILE" "$state_dir/lumen.env.before"
    install -m 0644 "$MANIFEST_FILE" "$state_dir/release-manifest.target.json"
  fi
  env_set LUMEN_LAST_UPGRADE_STATE "$state_dir"
}

main() {
  local -a backup_args
  require_root_or_dry_run
  [ -r "$MANIFEST_FILE" ] || die "--manifest is required"
  load_env
  validate_release_manifest "$MANIFEST_FILE"
  validate_panel_config
  BACKUP_PASSPHRASE_FILE="${BACKUP_PASSPHRASE_FILE:-${UPGRADE_BACKUP_PASSPHRASE_FILE:-}}"
  backup_args=(--config "$CONFIG_FILE")
  if [ -n "$BACKUP_PASSPHRASE_FILE" ]; then
    backup_args+=(--passphrase-file "$BACKUP_PASSPHRASE_FILE")
  elif [ "$ALLOW_PLAINTEXT_BACKUP" = "1" ] || [ "$DRY_RUN" = "1" ]; then
    backup_args+=(--allow-plaintext)
  else
    die "upgrade backup contains secrets; pass --backup-passphrase-file or explicit --allow-plaintext-backup"
  fi
  if [ "$DRY_RUN" = "1" ]; then
    backup_args+=(--dry-run)
  fi
  "$REPO_ROOT/scripts/backup.sh" "${backup_args[@]}"
  record_upgrade_state
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
  compose_run run --rm api alembic upgrade head
  compose_run up -d
  log "upgrade complete"
}

main "$@"
