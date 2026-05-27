#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
BACKUP_FILE=""
PASSPHRASE_FILE=""
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --backup) BACKUP_FILE="$2"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: restore.sh --backup PATH --force [--passphrase-file PATH]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

main() {
  local work archive
  require_root_or_dry_run
  [ "$FORCE" = "1" ] || die "restore is destructive; pass --force"
  [ -r "$BACKUP_FILE" ] || die "backup not readable"
  load_env
  if [ "$DRY_RUN" = "1" ]; then
    log "would restore $BACKUP_FILE"
    return 0
  fi
  work="$(mktemp -d)"
  trap 'rm -rf -- "$work"' EXIT
  archive="$BACKUP_FILE"
  if printf '%s' "$BACKUP_FILE" | grep -q '\.enc$'; then
    [ -r "$PASSPHRASE_FILE" ] || die "--passphrase-file required for encrypted backup"
    archive="$work/backup.tar.gz"
    openssl enc -d -aes-256-cbc -pbkdf2 -in "$BACKUP_FILE" -out "$archive" -pass "file:$PASSPHRASE_FILE"
  fi
  mkdir -p "$work/extract"
  tar -xzf "$archive" -C "$work/extract"
  install -m 0600 "$work/extract/config/lumen.env" "$CONFIG_FILE"
  load_env
  ensure_dirs
  cp -a "$work/extract/secrets/." "$LUMEN_SECRETS_DIR/" 2>/dev/null || true
  cp -a "$work/extract/data/." "$LUMEN_DATA_DIR/" 2>/dev/null || true
  compose_run up -d postgres redis
  compose exec -T postgres pg_restore --clean --if-exists -U lumen -d lumen <"$work/extract/db/postgres.dump"
  compose_run up -d
  log "restore complete"
}

main "$@"
