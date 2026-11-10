#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/runpod-slim/ComfyUI}"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
LATENT_UPSCALE_DIR="$COMFYUI_DIR/models/latent_upscale_models"
LORAS_DIR="$COMFYUI_DIR/models/loras"

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

mkdir -p "$CUSTOM_NODES_DIR" "$LATENT_UPSCALE_DIR" "$LORAS_DIR"

clone_or_update \
    "https://github.com/sandpies/ComfyUI-H3-Video-Upsampler.git" \
    "$CUSTOM_NODES_DIR/ComfyUI-H3-Video-Upsampler"

wget -c \
    "https://huggingface.co/LBH-123-AI/Minimax_h3_latent_Upscaler/resolve/main/minimax_h3_latent_upscaler_3d_conv_v1/minimax_h3_latent_upscaler_3d_conv_v1_bf16.safetensors" \
    -O "$LATENT_UPSCALE_DIR/minimax_h3_latent_upscaler_3d_conv_v1_bf16.safetensors"

wget -c \
    "https://huggingface.co/sandpies/ComfyUI-H3-Video-Upsampler/resolve/main/lora/open_h3_regenerate_2k_r256pp_bf16.safetensors" \
    -O "$LORAS_DIR/open_h3_regenerate_2k_r256pp_bf16.safetensors"

echo "H3 Video Upsampler setup completed."
