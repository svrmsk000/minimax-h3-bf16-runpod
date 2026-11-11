#!/usr/bin/env bash
set -Eeuo pipefail

COMFY="${COMFY:-/workspace/runpod-slim/ComfyUI}"
SETUP_LIB="${MINIMAX_H3_SETUP_LIB:-/opt/minimax-h3/minimax_h3_download_setup.sh}"

if [ ! -s "$SETUP_LIB" ]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  SETUP_LIB="$SCRIPT_DIR/minimax_h3_download_setup.sh"
fi

if [ ! -s "$SETUP_LIB" ]; then
  echo "ERROR: MiniMax H3 download library not found: $SETUP_LIB" >&2
  exit 1
fi

export COMFY
export MINIMAX_H3_SETUP_LIB_ONLY=1
source "$SETUP_LIB"

echo "=== Manual MiniMax H3 model download ==="
echo "ComfyUI: $COMFY"
echo "GPU family: ${GPU_FAMILY}"

init_model_manifest
resolve_dynamic_model_sizes
prepare_local_models
preflight_remote_models
preflight_disk_space

all_downloads=("${!DOWNLOAD_OUTPUTS[@]}")
download_group "MINIMAX-H3-MANUAL" "${all_downloads[@]}"
validate_all_models

echo "=== All enabled MiniMax H3 models downloaded and validated successfully ==="
