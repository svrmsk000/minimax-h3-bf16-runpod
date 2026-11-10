#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

comfy="$tmp/ComfyUI"
venv="$tmp/sglang-venv"
mkdir -p "$comfy/models/diffusion_models/h3" "$comfy/models/text_encoders" "$comfy/models/vae" "$venv/bin"
for model_file in \
  "$comfy/models/diffusion_models/h3/minimax_h3_ref2va_bf16.safetensors" \
  "$comfy/models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors" \
  "$comfy/models/vae/minimax_h3_video_vae_fp16.safetensors" \
  "$comfy/models/vae/minimax_h3_audio_vae_fp32.safetensors"; do
  printf 'mock model weights' > "$model_file"
done

cat > "$venv/bin/sglang" <<'FAKE_SGLANG'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_SGLANG_ARGS_FILE"
printf 'PYTORCH_CUDA_ALLOC_CONF=%s\n' "${PYTORCH_CUDA_ALLOC_CONF:-}" >> "$FAKE_SGLANG_ARGS_FILE"
FAKE_SGLANG
chmod +x "$venv/bin/sglang"

export COMFY="$comfy"
export SGLANG_VENV="$venv"
export HF_HOME="$tmp/hf"
export FAKE_SGLANG_ARGS_FILE="$tmp/args.txt"
launcher="$repo_root/sglang/start_minimax_h3_ref2va.sh"

assert_pair() {
  local flag="$1" value="$2"
  grep -Fqx -- "$flag" "$FAKE_SGLANG_ARGS_FILE"
  grep -Fqx -- "$value" "$FAKE_SGLANG_ARGS_FILE"
}

run_profile() {
  local gpu_count="$1"
  "$launcher" "$gpu_count"
  assert_pair --num-gpus "$gpu_count"
  assert_pair --model-variant ref2va
  assert_pair --performance-mode memory
  assert_pair --layerwise-offload-components dit,text_encoder,vae
  assert_pair --enable-torch-compile false
  assert_pair --warmup-resolutions 1344x768
  assert_pair --warmup-num-frames 124
  assert_pair --host 0.0.0.0
  assert_pair --port 30010
  grep -Fqx 'PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' "$FAKE_SGLANG_ARGS_FILE"
}

run_profile 1
assert_pair --dit-layerwise-resident-layers 4
assert_pair --layerwise-resident-layers video_vae=36
if grep -Eq '^--(tp-size|ulysses-degree|encoder-parallel|dit-offload-prefetch-size)$' "$FAKE_SGLANG_ARGS_FILE"; then
  echo "One-GPU profile unexpectedly contains multi-GPU options." >&2
  exit 1
fi

run_profile 2
assert_pair --tp-size 2
assert_pair --ulysses-degree 1
assert_pair --encoder-parallel auto
assert_pair --dit-offload-prefetch-size 1
assert_pair --dit-layerwise-resident-layers 20

run_profile 4
assert_pair --tp-size 2
assert_pair --ulysses-degree 2
assert_pair --encoder-parallel auto
assert_pair --dit-offload-prefetch-size 1
assert_pair --dit-layerwise-resident-layers 20

if "$launcher" 3 >/dev/null 2>&1; then
  echo "Unsupported GPU count was accepted." >&2
  exit 1
fi

echo "SGLang 1/2/4 GPU launch-profile tests passed."
