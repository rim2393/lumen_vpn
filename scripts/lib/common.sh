#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN="${DRY_RUN:-${LUMEN_DRY_RUN:-0}}"
CONFIG_FILE="${CONFIG_FILE:-/opt/lumen/.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$REPO_ROOT/deploy/compose/lumen.yml}"

log() { printf '[lumen] %s\n' "$*" >&2; }
warn() { printf '[lumen][warn] %s\n' "$*" >&2; }
die() { printf '[lumen][error] %s\n' "$*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[lumen][dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

require_root_or_dry_run() {
  [ "$DRY_RUN" = "1" ] && return 0
  [ "$(id -u)" -eq 0 ] || die "Run as root or pass --dry-run."
}

ensure_config() {
  if [ -f "$CONFIG_FILE" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run config not found at $CONFIG_FILE; reading $REPO_ROOT/.env.example"
    log "dry-run leaves generated values unwritten; production secrets belong only in a private config path"
    CONFIG_FILE="$REPO_ROOT/.env.example"
    return 0
  fi
  run mkdir -p "$(dirname "$CONFIG_FILE")"
  run install -m 0600 "$REPO_ROOT/.env.example" "$CONFIG_FILE"
}

load_env() {
  ensure_config
  # shellcheck disable=SC1090
  set -a && source "$CONFIG_FILE" && set +a
  LUMEN_HOME="${LUMEN_HOME:-/opt/lumen}"
  LUMEN_DATA_DIR="${LUMEN_DATA_DIR:-$LUMEN_HOME/data}"
  LUMEN_BACKUP_DIR="${LUMEN_BACKUP_DIR:-$LUMEN_HOME/backups}"
  LUMEN_SUPPORT_DIR="${LUMEN_SUPPORT_DIR:-$LUMEN_HOME/support-bundles}"
  LUMEN_SECRETS_DIR="${LUMEN_SECRETS_DIR:-$LUMEN_HOME/secrets}"
  TLS_CERT_DIR="${TLS_CERT_DIR:-/etc/nginx/lumen/certs}"
}

env_value() {
  grep -E "^$1=" "$CONFIG_FILE" | tail -n 1 | cut -d= -f2- || true
}

env_set() {
  local key="$1" value="$2" tmp
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would write $key to $CONFIG_FILE (value suppressed; file unchanged)"
    return 0
  fi
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" { print key "=" value; done = 1; next }
    { print }
    END { if (done == 0) print key "=" value }
  ' "$CONFIG_FILE" >"$tmp"
  install -m 0600 "$tmp" "$CONFIG_FILE"
  rm -f "$tmp"
}

random_secret() {
  if have_cmd openssl; then
    openssl rand -base64 48 | tr -d '\n'
  else
    dd if=/dev/urandom bs=48 count=1 2>/dev/null | base64 | tr -d '\n'
  fi
}

ensure_secret() {
  local key="$1" current
  current="$(env_value "$key")"
  case "$current" in
    ""|GENERATED_AT_INSTALL|GENERATE|CHANGE_ME)
      if [ "$DRY_RUN" = "1" ]; then
        env_set "$key" "<generated>"
      else
        env_set "$key" "$(random_secret)"
        log "generated $key"
      fi
      ;;
  esac
}

ensure_dirs() {
  run mkdir -p "$LUMEN_HOME" "$LUMEN_DATA_DIR" "$LUMEN_BACKUP_DIR" "$LUMEN_SUPPORT_DIR" "$LUMEN_SECRETS_DIR"
  run chmod 0700 "$LUMEN_SECRETS_DIR"
}

compose() {
  if have_cmd docker && docker compose version >/dev/null 2>&1; then
    docker compose --env-file "$CONFIG_FILE" -f "$COMPOSE_FILE" "$@"
  elif have_cmd docker-compose; then
    docker-compose --env-file "$CONFIG_FILE" -f "$COMPOSE_FILE" "$@"
  else
    die "Docker Compose is required"
  fi
}

compose_run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[lumen][dry-run] docker compose --env-file %q -f %q' "$CONFIG_FILE" "$COMPOSE_FILE" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  compose "$@"
}

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

allow_unpinned_images() {
  truthy "${LUMEN_ALLOW_UNPINNED_IMAGES:-0}"
}

skip_image_pull() {
  truthy "${LUMEN_SKIP_IMAGE_PULL:-0}"
}

normalize_placeholder_image_refs() {
  local key value stripped
  allow_unpinned_images || return 0
  for key in "$@"; do
    value="${!key:-}"
    if printf '%s' "$value" | grep -Eq '@sha256:0{64}$'; then
      stripped="${value%@sha256:*}"
      printf -v "$key" '%s' "$stripped"
      export "$key"
      warn "$key uses placeholder digest; using tag-only image because LUMEN_ALLOW_UNPINNED_IMAGES is enabled"
    fi
  done
}

validate_image_refs() {
  local strict="${1:-warn}" key value bad=0
  if [ "$#" -gt 0 ]; then
    shift
  fi
  [ "$#" -gt 0 ] || die "validate_image_refs requires at least one image variable"
  normalize_placeholder_image_refs "$@"
  for key in "$@"; do
    value="${!key:-}"
    if [ -z "$value" ]; then
      warn "$key is empty"
      bad=1
    elif ! printf '%s' "$value" | grep -Eq '@sha256:[0-9a-f]{64}$'; then
      warn "$key is not pinned by digest"
      bad=1
    elif printf '%s' "$value" | grep -Eq '@sha256:0{64}$'; then
      warn "$key has placeholder digest"
      bad=1
    fi
  done
  if [ "$strict" = "strict" ] && [ "$DRY_RUN" != "1" ] && [ "$bad" -ne 0 ]; then
    if allow_unpinned_images; then
      warn "allowing unpinned/placeholder images because LUMEN_ALLOW_UNPINNED_IMAGES is enabled"
    else
      die "Refusing production run with unpinned/placeholder images"
    fi
  fi
}

validate_images() {
  validate_image_refs "${1:-warn}" POSTGRES_IMAGE REDIS_IMAGE LUMEN_API_IMAGE LUMEN_WEB_IMAGE LUMEN_NODE_AGENT_IMAGE LUMEN_SUBSCRIPTION_IMAGE
}

registry_login() {
  local host="${REGISTRY_HOST:-}" username="${REGISTRY_USERNAME:-}" token_file="${REGISTRY_TOKEN_FILE:-}"
  [ -n "$host" ] || return 0
  if [ -z "$username" ] || [ -z "$token_file" ]; then
    if truthy "${REGISTRY_REQUIRED:-0}"; then
      die "REGISTRY_REQUIRED is enabled, but REGISTRY_USERNAME or REGISTRY_TOKEN_FILE is empty"
    fi
    warn "registry credentials are not configured; image pull will work only for public images"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would authenticate Docker registry $host as $username using token file $token_file"
    return 0
  fi
  [ -r "$token_file" ] || die "registry token file is not readable"
  cat "$token_file" | docker login "$host" -u "$username" --password-stdin >/dev/null
}

compose_pull() {
  if skip_image_pull; then
    log "skipping docker compose pull because LUMEN_SKIP_IMAGE_PULL is enabled"
    return 0
  fi
  compose_run pull
}

validate_release_manifest() {
  local manifest="$1"
  have_cmd jq || die "jq is required"
  jq -e '
    .schema == "lumen.release.v1"
    and (.version | type == "string" and length > 0)
    and (.released_at | type == "string" and length > 0)
    and (.installer_min_version | type == "string" and length > 0)
    and (.free_node_limit | type == "number")
    and (.images.api | type == "string" and length > 0)
    and (.images.web | type == "string" and length > 0)
    and (.images.node_agent | type == "string" and length > 0)
    and (.images.subscription | type == "string" and length > 0)
    and ([.images.api, .images.web, .images.node_agent, .images.subscription] | all(test("@sha256:[0-9a-f]{64}$")))
    and (.signature.alg | type == "string" and length > 0)
    and (.signature.kid | type == "string" and length > 0)
    and (.signature.value | type == "string" and length > 0)
    and (.signature.kid != "release-signing-key-id")
    and (.signature.value != "BASE64_SIGNATURE_PLACEHOLDER")
  ' "$manifest" >/dev/null || die "invalid release manifest"
}

validate_release_manifest_template() {
  local manifest="$1"
  have_cmd jq || die "jq is required"
  jq -e '
    .schema == "lumen.release.v1"
    and (.version | type == "string" and length > 0)
    and ([.images.api, .images.web, .images.node_agent, .images.subscription] | all(test("@sha256:[0-9a-f]{64}$")))
    and (.signature.value == "BASE64_SIGNATURE_PLACEHOLDER")
  ' "$manifest" >/dev/null || die "invalid release manifest template"
}

render_template() {
  local src="$1" dst="$2"
  if [ "$DRY_RUN" = "1" ]; then
    log "would render $src to $dst"
    return 0
  fi
  have_cmd envsubst || die "envsubst is required"
  envsubst '${PANEL_DOMAIN} ${SUBSCRIPTION_DOMAIN} ${AUTH_PORTAL_DOMAIN} ${TLS_CERT_DIR} ${LUMEN_API_PORT} ${LUMEN_WEB_PORT} ${LUMEN_SUBSCRIPTION_PORT}' <"$src" >"$dst"
}

redact_stream() {
  sed -E \
    -e 's#(PASSWORD|SECRET|TOKEN|PEPPER|KEY|SEED)=.*#\1=<redacted>#g' \
    -e 's#(password|secret|token|private_key|license_key)([" ]*[:=][" ]*)[^" ,]+#\1\2<redacted>#gi'
}

validate_domain() {
  local key="$1" value="$2"
  [ -n "$value" ] || die "$key is required"
  printf '%s' "$value" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$' \
    || die "$key must be a DNS hostname, got: $value"
}

validate_email() {
  local key="$1" value="$2"
  [ -n "$value" ] || die "$key is required"
  printf '%s' "$value" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' \
    || die "$key must be an email address"
}

validate_port() {
  local key="$1" value="$2"
  printf '%s' "$value" | grep -Eq '^[0-9]+$' || die "$key must be numeric"
  [ "$value" -ge 1 ] && [ "$value" -le 65535 ] || die "$key must be in range 1..65535"
}

validate_https_url() {
  local key="$1" value="$2"
  [ -n "$value" ] || die "$key is required"
  printf '%s' "$value" | grep -Eq '^https://[^[:space:]]+$' || die "$key must be an https URL"
}

is_example_domain() {
  printf '%s' "$1" | grep -Eqi '(^|\.)example\.(com|net|org)$'
}

check_distinct_host_ports() {
  local api="$1" web="$2" sub="$3"
  [ "$api" != "$web" ] || die "LUMEN_API_PORT and LUMEN_WEB_PORT cannot both be $api"
  [ "$api" != "$sub" ] || die "LUMEN_API_PORT and LUMEN_SUBSCRIPTION_PORT cannot both be $api"
  [ "$web" != "$sub" ] || die "LUMEN_WEB_PORT and LUMEN_SUBSCRIPTION_PORT cannot both be $web"
}

check_local_port_available() {
  local port="$1" label="$2"
  [ "$DRY_RUN" = "1" ] && return 0
  truthy "${LUMEN_SKIP_PORT_CHECK:-0}" && return 0
  if have_cmd ss && ss -ltn | awk '{print $4}' | grep -Eq "[:.]$port$"; then
    die "$label port $port is already listening on this host. Change the port in $CONFIG_FILE or stop the conflicting service."
  fi
}

validate_panel_config() {
  validate_domain PANEL_DOMAIN "${PANEL_DOMAIN:-}"
  validate_domain SUBSCRIPTION_DOMAIN "${SUBSCRIPTION_DOMAIN:-}"
  validate_email ACME_EMAIL "${ACME_EMAIL:-}"
  [ "$PANEL_DOMAIN" != "$SUBSCRIPTION_DOMAIN" ] || die "PANEL_DOMAIN and SUBSCRIPTION_DOMAIN must be different hostnames"
  if [ "$DRY_RUN" != "1" ]; then
    ! is_example_domain "$PANEL_DOMAIN" || die "PANEL_DOMAIN still uses an example domain"
    ! is_example_domain "$SUBSCRIPTION_DOMAIN" || die "SUBSCRIPTION_DOMAIN still uses an example domain"
  fi
  validate_port LUMEN_API_PORT "${LUMEN_API_PORT:-8080}"
  validate_port LUMEN_WEB_PORT "${LUMEN_WEB_PORT:-3000}"
  validate_port LUMEN_SUBSCRIPTION_PORT "${LUMEN_SUBSCRIPTION_PORT:-8081}"
  check_distinct_host_ports "${LUMEN_API_PORT:-8080}" "${LUMEN_WEB_PORT:-3000}" "${LUMEN_SUBSCRIPTION_PORT:-8081}"
}

validate_panel_ports_available() {
  check_local_port_available "${LUMEN_API_PORT:-8080}" "Panel API loopback"
  check_local_port_available "${LUMEN_WEB_PORT:-3000}" "Panel web loopback"
  check_local_port_available "${LUMEN_SUBSCRIPTION_PORT:-8081}" "Subscription loopback"
}

validate_node_config() {
  validate_https_url LUMEN_CONTROL_PLANE_URL "${LUMEN_CONTROL_PLANE_URL:-}"
  if [ "$DRY_RUN" != "1" ]; then
    ! printf '%s' "${LUMEN_CONTROL_PLANE_URL:-}" | grep -Eqi 'https://[^/]*example\.(com|net|org)(/|$)' \
      || die "LUMEN_CONTROL_PLANE_URL still uses an example domain"
  fi
}
