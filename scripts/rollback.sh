#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
STATE_DIR=""
BACKUP_FILE=""
PASSPHRASE_FILE=""
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --backup) BACKUP_FILE="$2"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: rollback.sh --force [--config PATH] [--state-dir PATH|--backup PATH] [--passphrase-file PATH] [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

restore_from_backup() {
  local -a restore_args
  restore_args=(--config "$CONFIG_FILE" --backup "$BACKUP_FILE" --force)
  if [ -n "$PASSPHRASE_FILE" ]; then
    restore_args+=(--passphrase-file "$PASSPHRASE_FILE")
  fi
  if [ "$DRY_RUN" = "1" ]; then
    restore_args+=(--dry-run)
  fi
  bash "$REPO_ROOT/scripts/restore.sh" "${restore_args[@]}"
}

restore_from_state_dir() {
  local before_env="$STATE_DIR/lumen.env.before"
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would restore $before_env to $CONFIG_FILE and restart compose"
    return 0
  fi
  [ -r "$before_env" ] || die "rollback state does not contain lumen.env.before: $STATE_DIR"
  install -m 0600 "$before_env" "$CONFIG_FILE"
  load_env
  validate_panel_config
  validate_images strict
  compose_run config >/dev/null
  compose_pull
  compose_run up -d
  log "rollback complete from $STATE_DIR"
}

main() {
  require_root_or_dry_run
  [ "$FORCE" = "1" ] || die "rollback changes runtime state; pass --force"
  if [ -n "$BACKUP_FILE" ]; then
    restore_from_backup
    return 0
  fi
  load_env
  STATE_DIR="${STATE_DIR:-${LUMEN_LAST_UPGRADE_STATE:-}}"
  [ -n "$STATE_DIR" ] || die "--state-dir is required when LUMEN_LAST_UPGRADE_STATE is not set"
  restore_from_state_dir
}

main "$@"
