#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/comfyui/comfyui"
bash -n "$service"
grep -Fq 'nohup setsid python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --preview-method none --high-ram --enable-manager' "$service"
grep -Fq 'restart|force-reload)' "$service"
grep -Fq 'COMFYUI_LOGFILE:-/tmp/comfyui.log' "$service"
echo "ComfyUI service script tests passed."
