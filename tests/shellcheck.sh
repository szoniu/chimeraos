#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck &>/dev/null; then
    echo "ERROR: shellcheck not found." >&2; exit 1
fi

echo "=== ShellCheck Lint ==="
errors=0; files=0
while IFS= read -r -d '' file; do
    (( files++ )) || true
    if ! shellcheck --shell=bash --severity=warning \
         --exclude=SC1091,SC2034,SC2154,SC1090,SC2155,SC2163 "${file}"; then
        (( errors++ )) || true
        echo "FAIL: ${file}"
    fi
done < <(find "${SCRIPT_DIR}" -name '*.sh' -not -path '*/\.*' -print0)

echo "=== Files: ${files}, Failures: ${errors} ==="
[[ ${errors} -eq 0 ]] && exit 0 || exit 1
