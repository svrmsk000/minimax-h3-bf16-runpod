#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
start="$repo_root/runpod_start.sh"
dockerfile="$repo_root/Dockerfile"
entrypoint="$repo_root/entrypoint.sh"
setup="$repo_root/minimax_h3_download_setup.sh"

bash -n "$start"
grep -Fq 'COPY runpod_start.sh /start.sh' "$dockerfile"
grep -Fq 'service comfyui start' "$start"
grep -Fq 'service comfyui stop' "$start"
grep -Fq 'service sgmax 1 stop' "$start"
grep -Fq 'setup_script="/opt/minimax-h3/minimax_h3_download_setup.sh"' "$entrypoint"
if grep -Eq 'SETUP_SCRIPT_URL|MINIMAX_H3_SETUP_SCRIPT_URL|curl .*setup_script' "$entrypoint"; then
  echo "Remote startup-script override is forbidden." >&2
  exit 1
fi
if grep -Eq 'SETUP_SCRIPT_URL|MINIMAX_H3_SETUP_SCRIPT_URL' "$setup"; then
  echo "Remote startup-script URL must not be used as an asset fallback." >&2
  exit 1
fi
grep -Fq 'test -x /workspace/runpod-slim/ComfyUI/.venv-cu130/bin/python' "$start"

if grep -En '(^|[[:space:]])(pip|pip3|uv)[[:space:]]+install|ensurepip|apt(-get)?[[:space:]]+install|git[[:space:]]+clone|python(3(\.[0-9]+)?)?[[:space:]]+main\.py' "$start"; then
  echo "Forbidden runtime installation or direct ComfyUI launch found in /start.sh replacement." >&2
  exit 1
fi

if [ "$(grep -Fc 'service comfyui start' "$start")" -ne 1 ]; then
  echo "Expected exactly one ComfyUI service start command." >&2
  exit 1
fi

echo "RunPod startup script tests passed."
