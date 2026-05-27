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
    run apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl gettext-base nginx jq docker.io docker-compose-plugin
    run systemctl enable --now docker
    run systemctl enable --now nginx
  else
    warn "apt-get not found; install Docker, Compose v2, Nginx, envsubst, openssl, curl manually"
  fi
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
  render_template "$REPO_ROOT/deploy/nginx/lumen-http-acme.conf.template" /etc/nginx/sites-available/lumen-http-acme.conf
  render_template "$REPO_ROOT/deploy/nginx/lumen-panel.conf.template" /etc/nginx/sites-available/lumen-panel.conf
  render_template "$REPO_ROOT/deploy/nginx/lumen-subscription.conf.template" /etc/nginx/sites-available/lumen-subscription.conf
  run ln -sfn /etc/nginx/sites-available/lumen-http-acme.conf /etc/nginx/sites-enabled/lumen-http-acme.conf
  run ln -sfn /etc/nginx/sites-available/lumen-panel.conf /etc/nginx/sites-enabled/lumen-panel.conf
  run ln -sfn /etc/nginx/sites-available/lumen-subscription.conf /etc/nginx/sites-enabled/lumen-subscription.conf
  compose_run config >/dev/null
  compose_run pull
  compose_run up -d
  log "install scaffold complete: https://$PANEL_DOMAIN"
}

main "$@"
