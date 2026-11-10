#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/runpod-slim/ComfyUI}"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
DIFFUSION_DIR="$COMFYUI_DIR/models/diffusion_models"
VAE_DIR="$COMFYUI_DIR/models/vae"
ASR_DIR="$COMFYUI_DIR/models/asr"

clone_or_update() {
    local repo_url="$1"
    local target_dir="$2"

    if [[ -d "$target_dir/.git" ]]; then
        echo "Updating $(basename "$target_dir")..."
        git -C "$target_dir" pull --ff-only
    elif [[ -e "$target_dir" ]]; then
        echo "ERROR: $target_dir exists but is not a Git repository." >&2
        return 1
    else
        git clone "$repo_url" "$target_dir"
    fi
}

download_model() {
    local url="$1"
    local destination="$2"

    if [[ -s "$destination" ]]; then
        echo "Keeping existing model: $destination"
        return 0
    fi

    curl -fL --retry 10 --retry-delay 5 --retry-connrefused \
        -o "$destination" "$url"
}

mkdir -p "$CUSTOM_NODES_DIR" "$DIFFUSION_DIR" "$VAE_DIR" "$ASR_DIR"

clone_or_update \
    "https://github.com/PedroMarinhoDev/ComfyUI-Drama3.git" \
    "$CUSTOM_NODES_DIR/ComfyUI-Drama3"

clone_or_update \
    "https://github.com/sandpies/ComfyUI-Hand-Tie-Clips.git" \
    "$CUSTOM_NODES_DIR/ComfyUI-Hand-Tie-Clips"

download_model \
    "https://huggingface.co/PedroMarinhoDev/Drama-3-ComfyUI/resolve/main/drama3_fp8experts_bf16.safetensors" \
    "$DIFFUSION_DIR/drama3_fp8experts_bf16.safetensors"

download_model \
    "https://huggingface.co/PedroMarinhoDev/Drama-3-ComfyUI/resolve/main/drama3_codec.safetensors" \
    "$VAE_DIR/drama3_codec.safetensors"

download_model \
    "https://huggingface.co/PedroMarinhoDev/Qwen3-ASR-ComfyUI/resolve/main/qwen3_asr_1.7b_bf16.safetensors" \
    "$ASR_DIR/qwen3_asr_1.7b_bf16.safetensors"

download_model \
    "https://huggingface.co/PedroMarinhoDev/Qwen3-ASR-ComfyUI/resolve/main/qwen3_forced_aligner_0.6b_bf16.safetensors" \
    "$ASR_DIR/qwen3_forced_aligner_0.6b_bf16.safetensors"

echo
echo "Installed model files:"
ls -lh "$DIFFUSION_DIR/"
ls -lh "$VAE_DIR/"
ls -lh "$ASR_DIR/"

echo "Drama3, Qwen3 ASR and Hand-Tie-Clips setup completed."
