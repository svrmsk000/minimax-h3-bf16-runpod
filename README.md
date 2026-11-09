# RunPod ComfyUI MiniMax H3 — BF16 Ref2VA

A separate RunPod/ComfyUI deployment based on [Nightfall93/runpod-comfyui-minimax-h3](https://github.com/Nightfall93/runpod-comfyui-minimax-h3), adapted with permission from the upstream author.

## Model configuration

- **Ref2VA diffusion model:** `minimax_h3_ref2va_bf16.safetensors` — full BF16, 66,280,487,368 bytes (about 61.7 GiB), pinned to Hugging Face revision `3f57e8291d2ef846f9a074b1b76d2767db434abe`.
- **FL2VA diffusion model:** upstream `minimax_h3_fl2va_pruned_int8_convrot.safetensors` is retained.
- **Text encoder:** official Comfy-Org Qwen3-VL-32B INT8 ConvRot (`qwen3vl_32b_minimax_h3_int8_convrot.safetensors`), pinned to Hugging Face revision `3f57e8291d2ef846f9a074b1b76d2767db434abe`.
- **VAEs:** upstream FP32 audio VAE and FP16 video VAE are retained.
- Seed Hunter auxiliary models, custom nodes, ComfyUI core, Pixaroma H3, SageAttention build matrix, startup/preflight logic, and the twelve workflows are retained.

The BF16 Ref2VA weights are downloaded to the container disk on first startup. They are not baked into the Docker image. The five base assets plus the pinned Ref2VA Turbo 4-step LoRA total approximately 122.16 GB (113.8 GiB), before the additional Seed Hunter assets, generated output, and safety reserve. The LoRA is downloaded into `models/loras/` before ComfyUI starts. Configure **at least 150 GB Container Disk**; 160 GB or more gives more practical headroom.

A 32 GB GPU does not mean the full BF16 weights fit entirely in VRAM. Actual generation depends on ComfyUI's model offload behavior, system RAM, resolution, frame count, and workflow settings. This repository does not promise that every BF16 workflow will fit a given GPU configuration.

## RunPod template

GitHub Actions builds the legacy image from `main` and the dedicated RTX 5090 image from `rtx5090-comfyui-0.42.1`:

- Ada (compute capability 8.9; RTX 40/L40/L40S): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-ada`
- Blackwell legacy image (compute capability 12.0): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-blackwell` (ComfyUI v0.34.0)\n- RTX 5090 image (compute capability 12.0; ComfyUI v0.42.1): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-rtx5090-comfyui-0.42.1` (ComfyUI only)\n- RTX 5090 + SGLang image (ComfyUI v0.42.1): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-rtx5090-comfyui-0.42.1-sglang`

Expose HTTP ports `8188`, `8080`, `8888`, and `30010`; leave the container start command empty. The setup script, workflows, and prompt resources are baked into the image. Set `SETUP_SCRIPT_URL` only when you want a pod to use a newer setup script without rebuilding the image:

```text
SETUP_SCRIPT_URL=https://raw.githubusercontent.com/svrmsk000/minimax-h3-bf16-runpod/sglang-rtx5090-comfyui-0.42.1/minimax_h3_download_setup.sh
```

## Supported environment variables

- `FILEBROWSER_USERNAME`
- `FILEBROWSER_PASSWORD` (at least 12 characters)
- `JUPYTER_PASSWORD`
- `HF_TOKEN` (optional; recommended for Hugging Face rate limits)
- `NTFY_TOPIC`, `NTFY_SERVER_URL`, `NTFY_TOKEN`
- `MINIMAX_H3_FIRST_MODEL` (`ref2va` by default; use `fl2va` to reverse foreground/background model order)
- `MINIMAX_H3_DOWNLOAD_JOBS` (default 2; allowed 1–4)
- `MINIMAX_H3_DISK_RESERVE_GB` (default 10)
- `MINIMAX_H3_MIN_DOWNLOAD_MIBPS` (default 5)
- `MINIMAX_H3_RECONNECT_LIMIT` (default 3 per file)
- `MINIMAX_H3_VERIFY_SHA256=1` (optional full SHA256 pass)
- `MINIMAX_H3_REFRESH_WORKFLOWS=1`
- `MINIMAX_H3_REFRESH_MEDIA=1`
- `ENABLE_SAGE_ATTENTION=0` (emergency opt-out; Sage is required by default)
- `SAGE_ATTENTION_RUNTIME_SMOKE=0` (skip the startup CUDA-kernel smoke test)
- `MINIMAX_H3_ENABLE_SGLANG=1` (start SGLang Diffusion Ref2VA on port 30010 alongside the RunPod services)
- `SGLANG_VENV` (optional isolated SGLang virtualenv path; default `/opt/minimax-h3/sglang-venv`)
- `SGLANG_DIT_RESIDENT_LAYERS` (default 4)
- `SGLANG_VIDEO_VAE_RESIDENT_LAYERS` (default 36)
- `SGLANG_WARMUP_RESOLUTIONS` (default `1344x768`)
- `SGLANG_WARMUP_NUM_FRAMES` (default 124)

## SGLang Diffusion (RTX 5090)

The dedicated branch `sglang-rtx5090-comfyui-0.42.1` adds an optional SGLang Diffusion Ref2VA server without replacing ComfyUI 0.42.1 or its Python environment.

SGLang Diffusion is installed and import-validated in a separate virtual environment at `/opt/minimax-h3/sglang-venv` while the Docker image is being built. No SGLang package installation occurs during Pod startup. Set `MINIMAX_H3_ENABLE_SGLANG=1` in the RunPod template to launch the preinstalled server on port `30010`; leave it unset or set it to `0` to skip SGLang. ComfyUI remains available on port `8188` and its Python/PyTorch environment is not modified.

SGLang uses the official model repository ID `MiniMaxAI/MiniMax-H3` for model configuration and resolves the already-downloaded local component weights through explicit overrides:

- Ref2VA BF16 transformer: `models/diffusion_models/h3/minimax_h3_ref2va_bf16.safetensors`
- Qwen3-VL INT8 ConvRot text encoder: `models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors`
- FP16 video VAE: `models/vae/minimax_h3_video_vae_fp16.safetensors`
- FP32 audio VAE: `models/vae/minimax_h3_audio_vae_fp32.safetensors`

This avoids downloading another copy of the large model weights. Hugging Face may still be used for small model configuration/tokenizer metadata; set `HF_TOKEN` if access or rate limits require it.

The SGLang server is configured for one GPU, Ref2VA, memory-oriented layerwise offload, four resident DiT layers, 36 resident video-VAE layers, 1344x768 warmup, 124 frames, and port 30010. These are configurable through the environment variables listed above.

**Do not run a ComfyUI H3 generation and an SGLang generation at the same time on the same RTX 5090.** Both services are exposed for convenience, but they share one GPU. The SGLang launcher checks that all four local model files exist before starting.

To keep the ComfyUI-only behavior, leave `MINIMAX_H3_ENABLE_SGLANG` unset or set it to `0`.

## Preserved stack

- RunPod CUDA 13.0 base image and PyTorch CUDA 13.0
- ComfyUI v0.42.1 with native MiniMax H3 support on the RTX 5090 branch; legacy `main` remains on v0.34.0
- ComfyUI-Pixaroma H3 audio-sync nodes
- SageAttention 2.2.0 for Ada and SageAttention 3 for Blackwell
- Eleven pinned Seed Hunter custom-node repositories
- RIFE v4.26 interpolation model
- Twelve managed workflow JSONs, including FL2VA, Ref2VA, audio-sync, five-seed Ref2VA Seed Hunter, and Seed Hunter upscale/continuation
- Existing prompt-formula and reference resources under `resources/`

Large model files are downloaded on pod startup, not stored in this repository or baked into the image.

## Sample media

The upstream workflow JSONs and runtime components are preserved. The upstream demonstration media files are not copied into this repository; upload your own reference images, videos, and audio in ComfyUI before running workflows that expect sample inputs.

## Validation

Run locally from Linux or Git Bash:

```bash
bash ./tests/run_all.sh
```

The test suite validates driver and GPU architecture gates, SageAttention build selection, safetensors headers, resumable downloads, manifest integrity, workflow JSON, model coverage, Linux model paths, required H3 nodes, and Seed Hunter node-lock coverage.

## Upstream attribution

Based on [Nightfall93/runpod-comfyui-minimax-h3](https://github.com/Nightfall93/runpod-comfyui-minimax-h3). Adapted with permission from the upstream author. Original upstream components and attribution are retained; see the upstream repository for its history.
