#!/usr/bin/env bash
set -euo pipefail

VENV="${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}"
MODEL_DIR="${MINIMAX_H3_SGLANG_MODEL_ID:-MiniMaxAI/MiniMax-H3}"
GPU_COUNT="${1:-1}"

if [ ! -x "$VENV/bin/sglang" ]; then
  echo "FATAL: SGLang is not installed at $VENV/bin/sglang." >&2
  exit 1
fi

case "$GPU_COUNT" in
  1)
    PARALLEL_ARGS=()
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS:-4}"
    VIDEO_VAE_RESIDENT_LAYERS="${SGLANG_VIDEO_VAE_RESIDENT_LAYERS_1GPU:-${SGLANG_VIDEO_VAE_RESIDENT_LAYERS:-24}}"
    PREFETCH_ARGS=()
    ;;
  2)
    PARALLEL_ARGS=(--tp-size 2 --ulysses-degree 1 --encoder-parallel auto)
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS_2GPU:-20}"
    VIDEO_VAE_RESIDENT_LAYERS="${SGLANG_VIDEO_VAE_RESIDENT_LAYERS_2GPU:-${SGLANG_VIDEO_VAE_RESIDENT_LAYERS:-36}}"
    PREFETCH_ARGS=(--dit-offload-prefetch-size 1)
    ;;
  4)
    PARALLEL_ARGS=(--tp-size 2 --ulysses-degree 2 --encoder-parallel auto)
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS_4GPU:-20}"
    VIDEO_VAE_RESIDENT_LAYERS="${SGLANG_VIDEO_VAE_RESIDENT_LAYERS_4GPU:-${SGLANG_VIDEO_VAE_RESIDENT_LAYERS:-36}}"
    PREFETCH_ARGS=(--dit-offload-prefetch-size 1)
    ;;
  *)
    echo "ERROR: GPU count must be 1, 2, or 4; received: $GPU_COUNT" >&2
    exit 2
    ;;
esac

export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
export HF_HOME="${HF_HOME:-/workspace/runpod-slim/huggingface}"
# huggingface_hub reads HF_TOKEN from the environment; SGLang has no token CLI flag.
if [ -n "${HF_TOKEN:-}" ]; then
  export HF_TOKEN
  echo "Hugging Face authentication: HF_TOKEN is configured."
else
  echo "WARNING: HF_TOKEN is not set; Hugging Face downloads will be unauthenticated." >&2
fi
mkdir -p "$HF_HOME"

echo "Starting MiniMax H3 Ref2VA with SGLang on $GPU_COUNT GPU(s)."
echo "Hugging Face model source: $MODEL_DIR"
echo "SGLang API: http://${SGLANG_HOST:-0.0.0.0}:${SGLANG_PORT:-30010}"

EXTRA_ARGS=()
if [ -n "${SGLANG_EXTRA_ARGS:-}" ]; then
  read -r -a EXTRA_ARGS <<< "$SGLANG_EXTRA_ARGS"
fi

exec "$VENV/bin/sglang" serve \
  --model-path "$MODEL_DIR" \
  --model-variant ref2va \
  --num-gpus "$GPU_COUNT" \
  "${PARALLEL_ARGS[@]}" \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  "${PREFETCH_ARGS[@]}" \
  --dit-layerwise-resident-layers "$RESIDENT_LAYERS" \
  --layerwise-resident-layers "video_vae=$VIDEO_VAE_RESIDENT_LAYERS" \
  --enable-torch-compile false \
  --warmup-resolutions "${SGLANG_WARMUP_RESOLUTIONS:-1344x768}" \
  --warmup-num-frames "${SGLANG_WARMUP_NUM_FRAMES:-124}" \
  --host "${SGLANG_HOST:-0.0.0.0}" \
  --port "${SGLANG_PORT:-30010}" \
  "${EXTRA_ARGS[@]}"
