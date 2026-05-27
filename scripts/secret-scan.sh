#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-.}"
FAIL=0

scan() {
  name="$1"
  pattern="$2"
  rg_path="$(command -v rg 2>/dev/null || true)"
  if [ -n "$rg_path" ] && [ -x "$rg_path" ]; then
    out="$("$rg_path" -n --hidden --glob '!.git/**' --glob '!backups/**' --glob '!support-bundles/**' -- "$pattern" "$ROOT" || true)"
  else
    out="$(grep -RInE --exclude-dir=.git --exclude-dir=backups --exclude-dir=support-bundles -- "$pattern" "$ROOT" || true)"
  fi
  if [ -n "$out" ]; then
    printf '[secret-scan] %s\n%s\n' "$name" "$out" >&2
    FAIL=1
  fi
}

scan "GitHub token" 'gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{40,}'
scan "AWS key" 'AKIA[0-9A-Z]{16}'
scan "private key" '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
scan "subscription token URL" 'https?://[^ ]+/api/sub/[A-Za-z0-9._~-]{20,}'

if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tracked="$(git -C "$ROOT" ls-files | grep -E '(^|/)(\.env|id_rsa|id_ed25519|.*\.(pem|p12|pfx|key))$' || true)"
  if [ -n "$tracked" ]; then
    printf '[secret-scan] sensitive tracked paths\n%s\n' "$tracked" >&2
    FAIL=1
  fi
fi

[ "$FAIL" -eq 0 ] || exit 1
echo "[secret-scan] ok"
