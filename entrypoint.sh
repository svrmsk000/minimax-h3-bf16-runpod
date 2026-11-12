#!/usr/bin/env bash
set -euo pipefail

echo "=== MiniMax H3 CUDA 13 ${MINIMAX_H3_GPU_FAMILY:-GPU} wrapper started ==="

# Reject an incompatible host before fetching a setup script or consuming model space.
bash /driver_preflight.sh

setup_script="/opt/minimax-h3/minimax_h3_download_setup.sh"
test -s "$setup_script"
bash -n "$setup_script"
chmod +x "$setup_script"
echo "Running MiniMax H3 cold-start setup..."
MINIMAX_H3_SKIP_MODEL_DOWNLOADS=1 bash "$setup_script"

echo "Running SageAttention bootstrap..."
# Source the bootstrap so its selected Sage 2/Sage 3 backend environment is
# inherited by the original RunPod start script.
source /sage_bootstrap.sh
sage_bootstrap_main

if [ "${MINIMAX_H3_ENABLE_SGLANG:-0}" = "1" ]; then
  echo "SGLang auto-start enabled; starting service sgmax."
  if [ ! -x "${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}/bin/sglang" ]; then
    echo "FATAL: SGLang is not preinstalled in the image at ${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}." >&2
    echo "Use the SGLang-enabled image tag; startup does not install packages." >&2
    exit 1
  fi
  service sgmax 1 start
else
  echo "SGLang auto-start disabled. Start it any time with: service sgmax 1 start (or choose 2/4 for a multi-GPU profile)"
fi

echo "Starting baked RunPod support services and the dedicated ComfyUI service..."
exec /start.sh
