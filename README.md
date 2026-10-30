# RunPod ComfyUI MiniMax H3 — BF16 Ref2VA

A separate RunPod/ComfyUI deployment based on [Nightfall93/runpod-comfyui-minimax-h3](https://github.com/Nightfall93/runpod-comfyui-minimax-h3), adapted with permission from the upstream author.

## Model configuration

- **Ref2VA diffusion model:** `minimax_h3_ref2va_bf16.safetensors` — full BF16, 66,280,487,368 bytes (about 61.7 GiB), pinned to Hugging Face revision `3f57e8291d2ef846f9a074b1b76d2767db434abe`.
- **FL2VA diffusion model:** upstream `minimax_h3_fl2va_pruned_int8_convrot.safetensors` is retained.
- **Text encoder:** upstream Qwen3-VL-32B NVFP4-AWQ is retained.
- **VAEs:** upstream FP32 audio VAE and FP16 video VAE are retained.
- Seed Hunter auxiliary models, custom nodes, ComfyUI core, Pixaroma H3, SageAttention build matrix, startup/preflight logic, and the twelve workflows are retained.

The BF16 Ref2VA weights are downloaded to the container disk on first startup. They are not baked into the Docker image. The five base assets plus the pinned Ref2VA Turbo 4-step LoRA total approximately 110.71 GB (103.1 GiB), before the additional Seed Hunter assets, generated output, and safety reserve. The LoRA is downloaded into `models/loras/` before ComfyUI starts. Configure **at least 150 GB Container Disk**; 160 GB or more gives more practical headroom.

A 32 GB GPU does not mean the full BF16 weights fit entirely in VRAM. Actual generation depends on ComfyUI's model offload behavior, system RAM, resolution, frame count, and workflow settings. This repository does not promise that every BF16 workflow will fit a given GPU configuration.

## RunPod template

GitHub Actions builds two images:

- Ada (compute capability 8.9; RTX 40/L40/L40S): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-ada`
- Blackwell (compute capability 12.0; RTX 50/RTX PRO Blackwell): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-blackwell`

Expose HTTP ports `8188`, `8080`, and `8888`; leave the container start command empty. The setup script, workflows, and prompt resources are baked into the image. Set `SETUP_SCRIPT_URL` only when you want a pod to use a newer setup script without rebuilding the image:

```text
SETUP_SCRIPT_URL=https://raw.githubusercontent.com/svrmsk000/minimax-h3-bf16-runpod/main/minimax_h3_download_setup.sh
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

## Preserved stack

- RunPod CUDA 13.0 base image and PyTorch CUDA 13.0
- ComfyUI v0.34.0 with native MiniMax H3 support
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
