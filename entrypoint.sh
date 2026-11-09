#!/usr/bin/env bash
set -euo pipefail

echo "=== MiniMax H3 CUDA 13 ${MINIMAX_H3_GPU_FAMILY:-GPU} wrapper started ==="

# Reject an incompatible host before fetching a setup script or consuming model space.
bash /driver_preflight.sh

downloaded_setup="/tmp/minimax_h3_download_setup.sh"
baked_setup="/opt/minimax-h3/minimax_h3_download_setup.sh"
setup_script="$baked_setup"
script_url="${SETUP_SCRIPT_URL:-${MINIMAX_H3_SETUP_SCRIPT_URL:-}}"

if [ -n "$script_url" ]; then
  echo "Downloading setup script from: $script_url"
  if curl -L --fail --silent --show-error --retry 5 --retry-all-errors --retry-delay 5 \
    --connect-timeout 30 --speed-limit 1024 --speed-time 15 \
    -o "${downloaded_setup}.part" "$script_url"; then
    mv "${downloaded_setup}.part" "$downloaded_setup"
    setup_script="$downloaded_setup"
    echo "Using downloaded MiniMax H3 setup script."
  else
    rm -f "${downloaded_setup}.part"
    echo "WARNING: Setup-script download failed; using the image-baked fallback."
  fi
else
  echo "No setup URL configured; using the image-baked MiniMax H3 setup script."
fi

test -s "$setup_script"
bash -n "$setup_script"
chmod +x "$setup_script"
echo "Running MiniMax H3 cold-start setup..."
bash "$setup_script"

echo "Running SageAttention bootstrap..."
# Source the bootstrap so its selected Sage 2/Sage 3 backend environment is
# inherited by the original RunPod start script.
source /sage_bootstrap.sh
sage_bootstrap_main

if [ "${MINIMAX_H3_ENABLE_SGLANG:-0}" = "1" ]; then
  echo "SGLang mode enabled; ComfyUI 0.42.1 will remain available on port 8188."
  if [ ! -x "${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}/bin/sglang" ]; then
    echo "FATAL: SGLang is not preinstalled in the image at ${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}." >&2
    echo "Use the SGLang-enabled image tag; startup does not install packages." >&2
    exit 1
  fi

  bash /opt/minimax-h3/sglang/start_minimax_h3_ref2va.sh &
  SGLANG_PID=$!

  /start.sh &
  COMFY_PID=$!

  cleanup() {
    set +e
    kill "$SGLANG_PID" "$COMFY_PID" 2>/dev/null
    wait "$SGLANG_PID" "$COMFY_PID" 2>/dev/null
  }
  trap cleanup EXIT INT TERM

  echo "SGLang PID: $SGLANG_PID; RunPod services PID: $COMFY_PID"
  set +e
  wait -n "$SGLANG_PID" "$COMFY_PID"
  status=$?
  set -e
  echo "One of the SGLang/RunPod service processes exited (status $status); stopping the other."
  exit "$status"
fi

echo "Starting original RunPod ComfyUI services..."
exec /start.sh
