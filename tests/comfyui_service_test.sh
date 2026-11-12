#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/comfyui/comfyui"
bash -n "$service"
grep -Fq 'nohup setsid "$PYTHON_BIN" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --preview-method none --high-ram --enable-manager "${extra_args[@]}"' "$service"
grep -Fq 'ARGS_FILE="${COMFY_ARGS_FILE:-/workspace/runpod-slim/comfyui_args.txt}"' "$service"
grep -Fq 'PYTHON_BIN="${COMFY_PYTHON_BIN:-${COMFY_VENV:-$COMFY/.venv-cu130}/bin/python}"' "$service"
grep -Fq 'read -r -a line_args <<< "$line"' "$service"
grep -Fq 'extra_args+=("$arg")' "$service"
grep -Fq 'if [ ! -x "$PYTHON_BIN" ]; then' "$service"
grep -Fq 'restart|force-reload)' "$service"
grep -Fq 'COMFYUI_LOGFILE:-/tmp/comfyui.log' "$service"
echo "ComfyUI service script tests passed."
