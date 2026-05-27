#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
FAILURES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: doctor.sh [--config PATH] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

check() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%-24s ok\n' "$name"
  else
    printf '%-24s fail\n' "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

main() {
  load_env
  check docker have_cmd docker
  check curl have_cmd curl
  check openssl have_cmd openssl
  check compose-render compose config
  validate_images warn || true
  if [ "${FREE_NODE_LIMIT:-}" = "3" ]; then
    printf '%-24s ok\n' "free-node-limit"
  else
    printf '%-24s fail\n' "free-node-limit"
    FAILURES=$((FAILURES + 1))
  fi
  if [ "$DRY_RUN" != "1" ] && have_cmd curl; then
    check panel-health curl -fsS "https://$PANEL_DOMAIN/api/healthz"
  fi
  [ "$FAILURES" -eq 0 ]
}

main "$@"

