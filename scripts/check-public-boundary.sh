#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-.}"
cd "$ROOT"

FAIL=0

forbidden_path='(^|/)(apps|packages|src|frontend|backend|api|web|node-agent)(/|$)'
forbidden_source_ext='\.((py|ts|tsx|js|jsx|go|rs|java|kt|cs|swift|php|rb))$'

while IFS= read -r path; do
  if [[ "$path" =~ $forbidden_path ]]; then
    printf '[boundary] forbidden private source path: %s\n' "$path" >&2
    FAIL=1
    continue
  fi

  if [[ "$path" =~ $forbidden_source_ext ]]; then
    printf '[boundary] forbidden application source file: %s\n' "$path" >&2
    FAIL=1
  fi
done < <(git ls-files --cached --others --exclude-standard)

if [ "$FAIL" -ne 0 ]; then
  cat >&2 <<'MSG'
[boundary] public repo may contain only installer scripts, deploy templates,
release manifests, and public operator docs. Private app source belongs in the
closed product repositories/images.
MSG
  exit 1
fi

echo "[boundary] public repo boundary ok"
