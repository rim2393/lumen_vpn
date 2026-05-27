#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
REDACT_IPS=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --redact-ips) REDACT_IPS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: support-bundle.sh [--config PATH] [--redact-ips] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sanitize() {
  if [ "$REDACT_IPS" = "1" ]; then
    redact_stream | sed -E 's#([0-9]{1,3}\.){3}[0-9]{1,3}#<ipv4>#g; s#([0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}#<ipv6>#g'
  else
    redact_stream
  fi
}

main() {
  require_root_or_dry_run
  load_env
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  out="$LUMEN_SUPPORT_DIR/lumen-support-$ts.tar.gz"
  if [ "$DRY_RUN" = "1" ]; then
    log "would create sanitized support bundle $out"
    return 0
  fi
  work="$(mktemp -d)"
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work"
  "$REPO_ROOT/scripts/doctor.sh" --config "$CONFIG_FILE" --dry-run >"$work/doctor.txt" 2>&1 || true
  compose logs --tail=300 >"$work/compose.log" 2>&1 || true
  sanitize <"$CONFIG_FILE" >"$work/lumen.env.redacted"
  run mkdir -p "$LUMEN_SUPPORT_DIR"
  tar -C "$work" -czf "$out" .
  chmod 0600 "$out"
  log "support bundle created: $out"
}

main "$@"
