#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
FORCE=0
NON_INTERACTIVE=0
SET_OVERRIDES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --set) SET_OVERRIDES+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: configure.sh [--config PATH] [--force] [--non-interactive] [--set KEY=VALUE] [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

set_kv() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" { print key "=" value; done = 1; next }
    { print }
    END { if (done == 0) print key "=" value }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

current_value() {
  local file="$1" key="$2"
  grep -E "^$key=" "$file" | tail -n 1 | cut -d= -f2- || true
}

prompt_value() {
  local file="$1" key="$2" label="$3" default value
  default="$(current_value "$file" "$key")"
  if [ "$NON_INTERACTIVE" = "1" ] || [ ! -t 0 ]; then
    return 0
  fi
  printf '%s [%s]: ' "$label" "$default" >&2
  IFS= read -r value
  [ -n "$value" ] || value="$default"
  set_kv "$file" "$key" "$value"
}

prompt_secret() {
  local file="$1" key="$2" label="$3" default value
  default="$(current_value "$file" "$key")"
  if [ "$NON_INTERACTIVE" = "1" ] || [ ! -t 0 ]; then
    return 0
  fi
  printf '%s [leave empty for %s]: ' "$label" "$default" >&2
  if have_cmd stty; then
    stty -echo
    IFS= read -r value
    stty echo
    printf '\n' >&2
  else
    IFS= read -r value
  fi
  [ -n "$value" ] || value="$default"
  set_kv "$file" "$key" "$value"
}

apply_override() {
  local file="$1" pair="$2" key value
  key="${pair%%=*}"
  value="${pair#*=}"
  [ -n "$key" ] && [ "$key" != "$pair" ] || die "--set expects KEY=VALUE"
  printf '%s' "$key" | grep -Eq '^[A-Z0-9_]+$' || die "invalid config key: $key"
  set_kv "$file" "$key" "$value"
}

main() {
  local target_config tmp pair
  require_root_or_dry_run
  target_config="$CONFIG_FILE"
  if [ -f "$CONFIG_FILE" ] && [ "$FORCE" != "1" ]; then
    die "$CONFIG_FILE already exists; pass --force to update it"
  fi

  tmp="$(mktemp)"
  if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$tmp"
  else
    cp "$REPO_ROOT/.env.example" "$tmp"
  fi
  chmod 0600 "$tmp"

  prompt_value "$tmp" PANEL_DOMAIN "Panel domain"
  prompt_value "$tmp" SUBSCRIPTION_DOMAIN "Subscription domain"
  prompt_value "$tmp" ACME_EMAIL "ACME email"
  prompt_value "$tmp" TZ "Timezone"
  prompt_value "$tmp" FIRST_ADMIN_EMAIL "First admin email"
  prompt_value "$tmp" FIRST_ADMIN_USERNAME "First admin username"
  prompt_secret "$tmp" FIRST_ADMIN_PASSWORD "First admin password"
  prompt_value "$tmp" REGISTRY_USERNAME "Registry username"
  prompt_value "$tmp" REGISTRY_TOKEN_FILE "Registry token file"
  prompt_value "$tmp" LICENSE_MODE "License mode"
  prompt_value "$tmp" FREE_NODE_LIMIT "Free node limit"
  prompt_value "$tmp" LUMEN_API_PORT "Panel API loopback port"
  prompt_value "$tmp" LUMEN_WEB_PORT "Panel web loopback port"
  prompt_value "$tmp" LUMEN_SUBSCRIPTION_PORT "Subscription loopback port"

  for pair in "${SET_OVERRIDES[@]}"; do
    apply_override "$tmp" "$pair"
  done

  CONFIG_FILE="$tmp"
  load_env
  validate_panel_config

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would write validated config to $target_config"
    rm -f "$tmp"
    return 0
  fi

  mkdir -p "$(dirname "$target_config")"
  install -m 0600 "$tmp" "$target_config"
  rm -f "$tmp"
  log "wrote $target_config with mode 0600"
  log "review it before running install.sh; secrets marked GENERATED_AT_INSTALL are generated during install"
}

main "$@"
