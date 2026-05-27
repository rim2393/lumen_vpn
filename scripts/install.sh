#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/lumen/.env"
ALLOW_UNPINNED_IMAGES=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --allow-unpinned-images) ALLOW_UNPINNED_IMAGES=1; shift ;;
    -h|--help) echo "Usage: install.sh [--config PATH] [--dry-run] [--allow-unpinned-images]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

install_packages() {
  if have_cmd apt-get; then
    run apt-get update
    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
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

main() {
  require_root_or_dry_run
  load_env
  ensure_dirs
  for key in POSTGRES_PASSWORD REDIS_PASSWORD JWT_SECRET REFRESH_SECRET API_TOKEN_PEPPER ENCRYPTION_KEY WEBHOOK_SIGNING_SECRET NODE_CA_SEED MANIFEST_SIGNING_SEED RECOVERY_KEY; do
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
  compose_run config >/dev/null
  compose_pull
  compose_run up -d
  log "install scaffold complete: https://$PANEL_DOMAIN"
}

main "$@"
