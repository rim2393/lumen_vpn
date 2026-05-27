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
  if ( "$@" ) >/dev/null 2>&1; then
    printf '%-24s ok\n' "$name"
  else
    printf '%-24s fail\n' "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

check_tls_file() {
  local domain="$1" file="$2"
  [ "$DRY_RUN" = "1" ] && return 0
  [ -n "$domain" ] || return 1
  [ -r "$TLS_CERT_DIR/$domain/$file" ]
}

check_local_port_listening() {
  local port="$1"
  [ "$DRY_RUN" = "1" ] && return 0
  have_cmd ss || return 1
  ss -ltn | awk '{print $4}' | grep -Eq "^(127\.0\.0\.1|\[::1\]|localhost)[:.]$port$|[:.]$port$"
}

validate_panel_runtime_ports() {
  check_local_port_listening "${LUMEN_API_PORT:-8080}" \
    && check_local_port_listening "${LUMEN_WEB_PORT:-3000}" \
    && check_local_port_listening "${LUMEN_SUBSCRIPTION_PORT:-8081}"
}

main() {
  load_env
  check docker have_cmd docker
  check curl have_cmd curl
  check openssl have_cmd openssl
  check nginx have_cmd nginx
  check config validate_panel_config
  check runtime-ports validate_panel_runtime_ports
  check panel-cert check_tls_file "$PANEL_DOMAIN" fullchain.pem
  check panel-key check_tls_file "$PANEL_DOMAIN" privkey.pem
  check subscription-cert check_tls_file "$SUBSCRIPTION_DOMAIN" fullchain.pem
  check subscription-key check_tls_file "$SUBSCRIPTION_DOMAIN" privkey.pem
  check compose-render compose config
  validate_images warn || true
  if [ "${FREE_NODE_LIMIT:-}" = "3" ]; then
    printf '%-24s ok\n' "free-node-limit"
  else
    printf '%-24s fail\n' "free-node-limit"
    FAILURES=$((FAILURES + 1))
  fi
  if [ "$DRY_RUN" != "1" ] && have_cmd curl; then
    check panel-health curl -fsS "https://$PANEL_DOMAIN/api/v1/health/live"
  fi
  [ "$FAILURES" -eq 0 ]
}

main "$@"
