#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export MINIMAX_H3_SETUP_LIB_ONLY=1
export MINIMAX_H3_STATUS_FILE="$tmp/minimax-h3-download.status"
source "$repo_root/minimax_h3_download_setup.sh"

GPU_FAMILY=ada
init_model_manifest
[ "${#DOWNLOAD_OUTPUTS[@]}" = "9" ]
[ "${SEED_HUNTER_DOWNLOADS[*]}" = "6 7 8" ]
[[ "${DOWNLOAD_OUTPUTS[5]}" = */models/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors ]]
[[ "${DOWNLOAD_OUTPUTS[6]}" = */models/vae/minimax_h3_video_vae_int8_convrot.safetensors ]]
[[ "${DOWNLOAD_OUTPUTS[7]}" = */models/latent_upscale_models/minimax_h3_latent_upscaler_3d_bf16.safetensors ]]
[[ "${DOWNLOAD_OUTPUTS[8]}" = */models/vae_approx/taeh3.safetensors ]]
remote_model_metadata() {
  printf '2100000000|%064d|%040d\\n' 0 0 | tr '0' 'a' | sed 's/a\{40\}$/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/'
}
resolve_dynamic_model_sizes >/dev/null
for size in "${DOWNLOAD_SIZES[@]}"; do
  [ "$size" = "2100000000" ]
done
for hash in "${DOWNLOAD_SHA256[@]}"; do
  [ "$hash" = "$(printf 'a%.0s' {1..64})" ]
done
for url in "${DOWNLOAD_URLS[@]}"; do
  [[ "$url" != *"/resolve/main/"* ]]
  [[ "$url" == *"/resolve/"* ]]
done

GPU_FAMILY=ampere
init_model_manifest
[ "${#DOWNLOAD_OUTPUTS[@]}" = "6" ]
[ "${#SEED_HUNTER_DOWNLOADS[@]}" = "0" ]
GPU_FAMILY=ada

MINIMAX_H3_FIRST_MODEL=ref2va select_model_priority >/dev/null
[ "$FIRST_MODEL_INDEX" = "1" ]
[ "$FIRST_MODEL_NAME" = "REF2VA" ]
[ "$DEFERRED_MODEL_INDEX" = "0" ]
[ "$DEFERRED_MODEL_NAME" = "FL2VA" ]

MINIMAX_H3_FIRST_MODEL=fl2va select_model_priority >/dev/null
[ "$FIRST_MODEL_INDEX" = "0" ]
[ "$FIRST_MODEL_NAME" = "FL2VA" ]
[ "$DEFERRED_MODEL_INDEX" = "1" ]
[ "$DEFERRED_MODEL_NAME" = "REF2VA" ]

MINIMAX_H3_FIRST_MODEL=invalid select_model_priority >/dev/null
[ "$FIRST_MODEL_INDEX" = "1" ]
[ "$FIRST_MODEL_NAME" = "REF2VA" ]
[ "$DEFERRED_MODEL_INDEX" = "0" ]
[ "$DEFERRED_MODEL_NAME" = "FL2VA" ]

"${PYTHON_TEST_BIN:-python3}" - "$tmp/source.safetensors" <<'PY'
import json
import struct
import sys

header = json.dumps({"tensor": {"dtype": "U8", "shape": [4], "data_offsets": [0, 4]}}).encode()
with open(sys.argv[1], "wb") as handle:
    handle.write(struct.pack("<Q", len(header)))
    handle.write(header)
    handle.write(b"test")
PY

mkdir -p "$tmp/models"
DOWNLOAD_KINDS=("MODEL")
DOWNLOAD_URLS=("file://$tmp/source.safetensors")
DOWNLOAD_OUTPUTS=("$tmp/models/deferred.safetensors")
DOWNLOAD_SIZES=("$(stat -c '%s' "$tmp/source.safetensors")")
DOWNLOAD_SHA256=("$(sha256_file "$tmp/source.safetensors")")
FIRST_MODEL_NAME="REF2VA"

download_group() {
  cp "$tmp/source.safetensors" "${DOWNLOAD_OUTPUTS[0]}"
}
notify_ntfy() {
  return 0
}

start_deferred_model_download "FL2VA" 0 >/dev/null
background_pid=$!
wait "$background_pid"
grep -q '^state=ready$' "$MINIMAX_H3_STATUS_FILE"
grep -q 'Both MiniMax H3 diffusion models' "$MINIMAX_H3_STATUS_FILE"
validate_model_file "${DOWNLOAD_OUTPUTS[0]}" "${DOWNLOAD_SIZES[0]}" "${DOWNLOAD_SHA256[0]}"

echo "Download-priority tests passed."
