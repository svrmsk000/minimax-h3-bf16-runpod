#!/usr/bin/env bash
set -euo pipefail

COMFY="${COMFY:-/workspace/runpod-slim/ComfyUI}"
VENV="${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}"
MODEL_DIR="${MINIMAX_H3_SGLANG_MODEL_ID:-MiniMaxAI/MiniMax-H3}"
GPU_COUNT="${1:-1}"

TRANSFORMER="${MINIMAX_H3_REF2VA_MODEL:-$COMFY/models/diffusion_models/h3/minimax_h3_ref2va_bf16.safetensors}"
TEXT_ENCODER="${MINIMAX_H3_TEXT_ENCODER:-$COMFY/models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors}"
VIDEO_VAE="${MINIMAX_H3_VIDEO_VAE:-$COMFY/models/vae/minimax_h3_video_vae_fp16.safetensors}"
AUDIO_VAE="${MINIMAX_H3_AUDIO_VAE:-$COMFY/models/vae/minimax_h3_audio_vae_fp32.safetensors}"

for file in "$TRANSFORMER" "$TEXT_ENCODER" "$VIDEO_VAE" "$AUDIO_VAE"; do
  if [ ! -s "$file" ]; then
    echo "FATAL: Required local MiniMax H3 component is missing: $file" >&2
    echo "Wait for the ComfyUI model setup/download to finish before starting SGLang." >&2
    exit 1
  fi
done

if [ ! -x "$VENV/bin/sglang" ]; then
  echo "FATAL: SGLang is not installed at $VENV/bin/sglang." >&2
  exit 1
fi

case "$GPU_COUNT" in
  1)
    PARALLEL_ARGS=()
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS:-4}"
    PREFETCH_ARGS=()
    ;;
  2)
    PARALLEL_ARGS=(--tp-size 2 --ulysses-degree 1 --encoder-parallel auto)
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS_2GPU:-20}"
    PREFETCH_ARGS=(--dit-offload-prefetch-size 1)
    ;;
  4)
    PARALLEL_ARGS=(--tp-size 2 --ulysses-degree 2 --encoder-parallel auto)
    RESIDENT_LAYERS="${SGLANG_DIT_RESIDENT_LAYERS_4GPU:-20}"
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
mkdir -p "$HF_HOME"

echo "Starting MiniMax H3 Ref2VA with SGLang on $GPU_COUNT GPU(s)."
echo "Model configuration/tokenizer source: $MODEL_DIR"
echo "Transformer, text encoder and VAEs: existing ComfyUI model files."
echo "SGLang API: http://${SGLANG_HOST:-0.0.0.0}:${SGLANG_PORT:-30010}"

EXTRA_ARGS=()
if [ -n "${SGLANG_EXTRA_ARGS:-}" ]; then
  read -r -a EXTRA_ARGS <<< "$SGLANG_EXTRA_ARGS"
fi

exec "$VENV/bin/sglang" serve \
  --model-path "$MODEL_DIR" \
  --component-weights-paths.transformer "$TRANSFORMER" \
  --component-weights-paths.text_encoder "$TEXT_ENCODER" \
  --component-weights-paths.video_vae "$VIDEO_VAE" \
  --component-weights-paths.audio_vae "$AUDIO_VAE" \
  --model-variant ref2va \
  --num-gpus "$GPU_COUNT" \
  "${PARALLEL_ARGS[@]}" \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  "${PREFETCH_ARGS[@]}" \
  --dit-layerwise-resident-layers "$RESIDENT_LAYERS" \
  --layerwise-resident-layers "video_vae=${SGLANG_VIDEO_VAE_RESIDENT_LAYERS:-36}" \
  --enable-torch-compile false \
  --warmup-resolutions "${SGLANG_WARMUP_RESOLUTIONS:-1344x768}" \
  --warmup-num-frames "${SGLANG_WARMUP_NUM_FRAMES:-124}" \
  --host "${SGLANG_HOST:-0.0.0.0}" \
  --port "${SGLANG_PORT:-30010}" \
  "${EXTRA_ARGS[@]}"
