#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

nvim=${NVIM:-nvim}
if [[ ${1:-} != "" && ${1:-} != "--smoke" ]] || [[ $# -gt 1 ]]; then
  printf 'Usage: bash tests/run.sh [--smoke]\n' >&2
  exit 2
fi

for test in syntax runtime pack debug native markview pack-integration; do
  "$nvim" -n -i NONE --headless -u NONE -l "tests/$test.lua"
done
bash tests/envrc.sh
if [[ ${1:-} == "--smoke" ]]; then
  "$nvim" -n -i NONE --headless -u NONE -l tests/smoke.lua
fi
