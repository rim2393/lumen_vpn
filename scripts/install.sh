#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
ALLOW_UNPINNED_IMAGES=0
INIT_CONFIG=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --init-config) INIT_CONFIG=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --allow-unpinned-images) ALLOW_UNPINNED_IMAGES=1; shift ;;
    -h|--help) echo "Usage: install.sh [--config PATH] [--init-config] [--dry-run] [--allow-unpinned-images]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

install_packages() {
  if have_cmd apt-get; then
    run apt-get update
    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl gettext-base nginx jq docker.io docker-compose-v2
    elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl gettext-base nginx jq docker.io docker-compose-plugin
    else
      run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl gettext-base nginx jq docker.io docker-compose
    fi
    run systemctl enable --now docker
    run systemctl enable --now nginx
  else
    warn "apt-get not found; install Docker, Compose v2, Nginx, envsubst, openssl, curl manually"
  fi
}

ensure_bootstrap_cert() {
  local domain="$1" cert_dir
  [ -n "$domain" ] || return 0
  cert_dir="$TLS_CERT_DIR/$domain"
  if [ -f "$cert_dir/fullchain.pem" ] && [ -f "$cert_dir/privkey.pem" ]; then
    return 0
  fi
  run mkdir -p "$cert_dir"
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would generate temporary self-signed TLS certificate for $domain"
    return 0
  fi
  openssl req -x509 -nodes -newkey rsa:2048 -days 14 \
    -subj "/CN=$domain" \
    -addext "subjectAltName=DNS:$domain" \
    -keyout "$cert_dir/privkey.pem" \
    -out "$cert_dir/fullchain.pem" >/dev/null 2>&1
  chmod 0600 "$cert_dir/privkey.pem"
  chmod 0644 "$cert_dir/fullchain.pem"
  warn "generated temporary self-signed TLS certificate for $domain; replace with ACME certificate before production"
}

acme_binary() {
  if have_cmd acme.sh; then
    command -v acme.sh
    return 0
  fi
  if [ -x "$HOME/.acme.sh/acme.sh" ]; then
    printf '%s\n' "$HOME/.acme.sh/acme.sh"
    return 0
  fi
  return 1
}

ensure_acme_sh() {
  local installer
  if acme_binary >/dev/null 2>&1; then
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would install acme.sh for ACME certificates"
    return 0
  fi
  installer="$(mktemp)"
  curl -fsSL https://get.acme.sh -o "$installer"
  run sh "$installer" "email=$ACME_EMAIL"
  rm -f "$installer"
}

issue_acme_cert() {
  local domain="$1" cert_dir acme issue_rc
  [ -n "$domain" ] || return 0
  truthy "${LUMEN_ACME_ENABLED:-true}" || {
    warn "ACME disabled; keeping bootstrap certificate for $domain"
    return 0
  }
  cert_dir="$TLS_CERT_DIR/$domain"
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run would issue ACME certificate for $domain using webroot /var/www/lumen-acme"
    return 0
  fi
  ensure_acme_sh
  acme="$(acme_binary)" || die "acme.sh install failed"
  run "$acme" --set-default-ca --server letsencrypt
  set +e
  run "$acme" --issue -d "$domain" -w /var/www/lumen-acme --keylength ec-256
  issue_rc=$?
  set -e
  if [ "$issue_rc" -ne 0 ]; then
    if [ "$issue_rc" -eq 2 ]; then
      warn "ACME certificate for $domain is already valid; installing existing certificate"
    else
      return "$issue_rc"
    fi
  fi
  run "$acme" --install-cert -d "$domain" --ecc \
    --fullchain-file "$cert_dir/fullchain.pem" \
    --key-file "$cert_dir/privkey.pem" \
    --reloadcmd "systemctl reload nginx"
  run chmod 0600 "$cert_dir/privkey.pem"
  run chmod 0644 "$cert_dir/fullchain.pem"
}

main() {
  local -a configure_args
  require_root_or_dry_run
  if [ "$INIT_CONFIG" = "1" ] || { [ ! -f "$CONFIG_FILE" ] && [ "$DRY_RUN" != "1" ] && [ -t 0 ]; }; then
    configure_args=(--config "$CONFIG_FILE")
    if [ "$INIT_CONFIG" = "1" ]; then
      configure_args+=(--force)
    fi
    bash "$REPO_ROOT/scripts/configure.sh" "${configure_args[@]}"
  fi
  load_env
  validate_panel_config
  validate_panel_ports_available
  ensure_dirs
  for key in POSTGRES_PASSWORD REDIS_PASSWORD JWT_SECRET REFRESH_SECRET API_TOKEN_PEPPER NODE_TOKEN_PEPPER SESSION_HASH_PEPPER LUMEN_BOOTSTRAP_ADMIN_API_KEY ENCRYPTION_KEY WEBHOOK_SIGNING_SECRET NODE_CA_SEED MANIFEST_SIGNING_SEED RECOVERY_KEY FIRST_ADMIN_PASSWORD; do
    ensure_secret "$key"
  done
  load_env
  if [ "$ALLOW_UNPINNED_IMAGES" = "1" ]; then
    LUMEN_ALLOW_UNPINNED_IMAGES=true
  fi
  validate_images strict
  install_packages
  registry_login
  run mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /var/www/lumen-acme "$TLS_CERT_DIR"
  ensure_bootstrap_cert "$PANEL_DOMAIN"
  ensure_bootstrap_cert "$SUBSCRIPTION_DOMAIN"
  render_template "$REPO_ROOT/deploy/nginx/lumen-http-acme.conf.template" /etc/nginx/sites-available/lumen-http-acme.conf
  render_template "$REPO_ROOT/deploy/nginx/lumen-panel.conf.template" /etc/nginx/sites-available/lumen-panel.conf
  render_template "$REPO_ROOT/deploy/nginx/lumen-subscription.conf.template" /etc/nginx/sites-available/lumen-subscription.conf
  run ln -sfn /etc/nginx/sites-available/lumen-http-acme.conf /etc/nginx/sites-enabled/lumen-http-acme.conf
  run ln -sfn /etc/nginx/sites-available/lumen-panel.conf /etc/nginx/sites-enabled/lumen-panel.conf
  run ln -sfn /etc/nginx/sites-available/lumen-subscription.conf /etc/nginx/sites-enabled/lumen-subscription.conf
  run nginx -t
  run systemctl reload nginx
  issue_acme_cert "$PANEL_DOMAIN"
  issue_acme_cert "$SUBSCRIPTION_DOMAIN"
  run nginx -t
  run systemctl reload nginx
  compose_run config >/dev/null
  compose_pull
  compose_run run --rm api alembic upgrade head
  compose_run up -d
  log "install scaffold complete: https://$PANEL_DOMAIN"
}

main "$@"
