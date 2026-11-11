#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/runpod-slim/ComfyUI}"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
LLM_DIR="$COMFYUI_DIR/models/LLM"
GEMMA_26B_DIR="$LLM_DIR/gemma-4-26b"

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

mkdir -p "$CUSTOM_NODES_DIR" "$GEMMA_26B_DIR"

clone_or_update \
    "https://github.com/duckyshell/ComfyUI-MiniMaxH3-Prompt-Writer.git" \
    "$CUSTOM_NODES_DIR/ComfyUI-MiniMaxH3-Prompt-Writer"

python3 -m pip install --only-binary=:all: \
    --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu130 \
    "llama-cpp-python>=0.3.34,<0.4"

export LD_LIBRARY_PATH="/usr/local/lib/python3.12/dist-packages/nvidia/cu13/lib:${LD_LIBRARY_PATH:-}"

wget -c \
    "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/resolve/main/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" \
    -O "$GEMMA_26B_DIR/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"

wget -c \
    "https://huggingface.co/unsloth/gemma-4-31B-it-GGUF/resolve/main/mmproj-BF16.gguf" \
    -O "$GEMMA_26B_DIR/mmproj-BF16.gguf"

wget -c \
    "https://huggingface.co/lightx2v/Minimax-h3-Turbo/resolve/main/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors" \
    -O "$LORAS_DIR/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"

echo "Gemma 4 26B Prompt Writer setup completed."
