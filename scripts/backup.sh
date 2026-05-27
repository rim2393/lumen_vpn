#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
PASSPHRASE_FILE=""
ALLOW_PLAINTEXT=0
BACKUP_WORK_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 ;;
    --allow-plaintext) ALLOW_PLAINTEXT=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: backup.sh [--config PATH] [--passphrase-file PATH|--allow-plaintext]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

cleanup_backup_work_dir() {
  [ -z "${BACKUP_WORK_DIR:-}" ] || rm -rf -- "$BACKUP_WORK_DIR"
}

main() {
  local ts out
  require_root_or_dry_run
  load_env
  [ -n "$PASSPHRASE_FILE" ] || [ "$ALLOW_PLAINTEXT" = "1" ] || die "backup contains secrets; use --passphrase-file or --allow-plaintext"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  out="$LUMEN_BACKUP_DIR/lumen-backup-$ts.tar.gz"
  run mkdir -p "$LUMEN_BACKUP_DIR"
  if [ "$DRY_RUN" = "1" ]; then
    log "would create backup $out"
    return 0
  fi
  BACKUP_WORK_DIR="$(mktemp -d)"
  trap cleanup_backup_work_dir EXIT
  mkdir -p "$BACKUP_WORK_DIR/db" "$BACKUP_WORK_DIR/config" "$BACKUP_WORK_DIR/secrets" "$BACKUP_WORK_DIR/data"
  compose exec -T postgres pg_dump -U lumen -d lumen --format=custom >"$BACKUP_WORK_DIR/db/postgres.dump"
  install -m 0600 "$CONFIG_FILE" "$BACKUP_WORK_DIR/config/lumen.env"
  cp -a "$LUMEN_SECRETS_DIR/." "$BACKUP_WORK_DIR/secrets/" 2>/dev/null || true
  cp -a "$LUMEN_DATA_DIR/uploads" "$BACKUP_WORK_DIR/data/" 2>/dev/null || true
  cp -a "$LUMEN_DATA_DIR/runtime" "$BACKUP_WORK_DIR/data/" 2>/dev/null || true
  tar -C "$BACKUP_WORK_DIR" -czf "$out" .
  chmod 0600 "$out"
  if [ -n "$PASSPHRASE_FILE" ]; then
    openssl enc -aes-256-cbc -pbkdf2 -salt -in "$out" -out "$out.enc" -pass "file:$PASSPHRASE_FILE"
    rm -f "$out"
    out="$out.enc"
  fi
  log "backup created: $out"
}

main "$@"
