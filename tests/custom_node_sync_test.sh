#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export MINIMAX_H3_SETUP_LIB_ONLY=1
export MINIMAX_H3_COMFY_BAKED="$tmp/baked"
export MINIMAX_H3_NODE_LOCK="$tmp/nodes.tsv"
export COMFY="$tmp/ComfyUI"
source "$repo_root/minimax_h3_download_setup.sh"

# Restore an incomplete persistent ComfyUI core even if its marker looks current.
mkdir -p "$COMFY_BAKED/comfy/text_encoders" "$COMFY_BAKED/comfy/ldm/minimax" "$COMFY_BAKED/comfy_extras" "$COMFY"
printf 'print("baked core")\n' > "$COMFY_BAKED/main.py"
printf '# core package\n' > "$COMFY_BAKED/comfy/__init__.py"
printf '# H3 nodes\n' > "$COMFY_BAKED/comfy_extras/nodes_minimax_h3.py"
printf '# text encoder\n' > "$COMFY_BAKED/comfy/text_encoders/minimax.py"
printf '# model\n' > "$COMFY_BAKED/comfy/ldm/minimax/model.py"
printf '%s\n' "$EXPECTED_CORE_COMMIT" > "$COMFY_BAKED/.minimax-h3-core-commit"
printf '%s\n' "$EXPECTED_CORE_COMMIT" > "$COMFY/.minimax-h3-core-commit"
mkdir -p "$VENV/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$VENV/bin/python"
chmod +x "$VENV/bin/python"
printf 'VIRTUAL_ENV="/opt/comfyui-venv"\n' > "$VENV/bin/activate"
ensure_comfyui >/dev/null
[ -f "$COMFY/main.py" ]
[ -f "$COMFY/comfy_extras/nodes_minimax_h3.py" ]
grep -Fq "VIRTUAL_ENV=\"$VENV\"" "$VENV/bin/activate"
grep -q "^$EXPECTED_CORE_COMMIT$" "$COMFY/.minimax-h3-core-commit"

printf '%s\t%s\t%s\n' \
  "ExampleNode" "https://example.invalid/node.git" "1111111111111111111111111111111111111111" \
  "ComfyUI-VFI" "https://example.invalid/vfi.git" "2222222222222222222222222222222222222222" \
  > "$NODE_LOCK"

for folder in ExampleNode ComfyUI-VFI; do
  mkdir -p "$COMFY_BAKED/custom_nodes/$folder"
done
printf '%s\n' "1111111111111111111111111111111111111111" \
  > "$COMFY_BAKED/custom_nodes/ExampleNode/.minimax-h3-managed-commit"
printf '%s\n' "2222222222222222222222222222222222222222" \
  > "$COMFY_BAKED/custom_nodes/ComfyUI-VFI/.minimax-h3-managed-commit"
mkdir -p "$COMFY_BAKED/custom_nodes/ComfyUI-VFI/rife/train_log"
truncate -s 24636301 "$COMFY_BAKED/custom_nodes/ComfyUI-VFI/rife/train_log/flownet.pkl"

# The SGLang custom node is also restored from the baked image.
mkdir -p "$COMFY_BAKED/custom_nodes/ComfyUI-MiniMaxH3-SGLang"
printf '%s\n' "mock node" > "$COMFY_BAKED/custom_nodes/ComfyUI-MiniMaxH3-SGLang/__init__.py"
printf '%s\n' "mock node source" > "$COMFY_BAKED/custom_nodes/ComfyUI-MiniMaxH3-SGLang/nodes.py"
printf '%s\n' "$H3_SGLANG_NODE_COMMIT" \
  > "$COMFY_BAKED/custom_nodes/ComfyUI-MiniMaxH3-SGLang/.minimax-h3-managed-commit"

# Manager must be restored from the baked image if a stale base copy exists.
export COMFYUI_MANAGER_COMMIT="15e49ea544a4b20627c2eec01341843e8c4b6d49"
mkdir -p "$COMFY_BAKED/custom_nodes/comfyui-manager"
printf 'baked manager\n' > "$COMFY_BAKED/custom_nodes/comfyui-manager/__init__.py"
printf '%s\n' "$COMFYUI_MANAGER_COMMIT" > "$COMFY_BAKED/custom_nodes/comfyui-manager/.minimax-h3-managed-commit"
mkdir -p "$COMFY/custom_nodes/comfyui-manager"
printf 'stale manager\n' > "$COMFY/custom_nodes/comfyui-manager/__init__.py"
ensure_comfyui_manager >/dev/null
grep -q '^baked manager$' "$COMFY/custom_nodes/comfyui-manager/__init__.py"
grep -q "^$COMFYUI_MANAGER_COMMIT$" "$COMFY/custom_nodes/comfyui-manager/.minimax-h3-managed-commit"
ensure_comfyui_manager >/dev/null
find "$COMFY/custom_nodes" -maxdepth 1 -type d -name 'comfyui-manager.pre-minimax-h3-*' | grep -q .

# Pixaroma H3 support must be restored from the baked source and pinned marker.
mkdir -p "$COMFY_BAKED/custom_nodes/ComfyUI-Pixaroma/nodes"
printf 'class PixaromaH3AudioSync: pass\n' > "$COMFY_BAKED/custom_nodes/ComfyUI-Pixaroma/nodes/node_h3_audio_sync.py"
printf '%s\n' "$PIXAROMA_COMMIT" > "$COMFY_BAKED/custom_nodes/ComfyUI-Pixaroma/.minimax-h3-managed-commit"
mkdir -p "$COMFY/custom_nodes/ComfyUI-Pixaroma/nodes"
printf 'stale node\n' > "$COMFY/custom_nodes/ComfyUI-Pixaroma/nodes/node_h3_audio_sync.py"
ensure_pixaroma_h3 >/dev/null
grep -q 'PixaromaH3AudioSync' "$COMFY/custom_nodes/ComfyUI-Pixaroma/nodes/node_h3_audio_sync.py"
grep -q "^$PIXAROMA_COMMIT$" "$COMFY/custom_nodes/ComfyUI-Pixaroma/.minimax-h3-managed-commit"

# Preserve an unmanaged user node while restoring managed SGLang and Seed Hunter nodes.
mkdir -p "$COMFY/custom_nodes/ExampleNode"
printf 'user copy\n' > "$COMFY/custom_nodes/ExampleNode/custom.txt"
GPU_FAMILY=ada
ensure_sglang_h3_node >/dev/null
[ -f "$COMFY/custom_nodes/ComfyUI-MiniMaxH3-SGLang/nodes.py" ]
grep -q "^$H3_SGLANG_NODE_COMMIT$" "$COMFY/custom_nodes/ComfyUI-MiniMaxH3-SGLang/.minimax-h3-managed-commit"
ensure_sglang_h3_node >/dev/null

ensure_seed_hunter_nodes >/dev/null
grep -q '^1111111111111111111111111111111111111111$' \
  "$COMFY/custom_nodes/ExampleNode/.minimax-h3-managed-commit"
[ -f "$COMFY/custom_nodes/ComfyUI-VFI/rife/train_log/flownet.pkl" ]
find "$COMFY/custom_nodes" -maxdepth 1 -type d -name 'ExampleNode.pre-minimax-h3-*' | grep -q .

# Ampere must skip Seed Hunter nodes.
COMFY="$tmp/ComfyUI-Ampere"
mkdir -p "$COMFY/custom_nodes"
GPU_FAMILY=ampere
ensure_seed_hunter_nodes >/dev/null
[ ! -e "$COMFY/custom_nodes/ExampleNode" ]

echo "Custom-node synchronization tests passed."
