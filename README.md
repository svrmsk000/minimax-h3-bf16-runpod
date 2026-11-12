# RunPod ComfyUI MiniMax H3 — BF16 Ref2VA

A separate RunPod/ComfyUI deployment based on [Nightfall93/runpod-comfyui-minimax-h3](https://github.com/Nightfall93/runpod-comfyui-minimax-h3), adapted with permission from the upstream author.

## Model configuration

- **Ref2VA diffusion model:** `minimax_h3_ref2va_bf16.safetensors` — full BF16, 66,280,487,368 bytes (about 61.7 GiB), pinned to Hugging Face revision `3f57e8291d2ef846f9a074b1b76d2767db434abe`.
- **FL2VA diffusion model:** upstream `minimax_h3_fl2va_pruned_int8_convrot.safetensors` is retained.
- **Text encoder:** official Comfy-Org Qwen3-VL-32B INT8 ConvRot (`qwen3vl_32b_minimax_h3_int8_convrot.safetensors`), pinned to Hugging Face revision `3f57e8291d2ef846f9a074b1b76d2767db434abe`.
- **VAEs:** upstream FP32 audio VAE and FP16 video VAE are retained.
- Seed Hunter auxiliary models, custom nodes, ComfyUI core, Pixaroma H3, SageAttention build matrix, startup/preflight logic, and the twelve workflows are retained.

The BF16 Ref2VA weights and other model assets are not baked into the Docker image and are not downloaded automatically by the current entrypoint. After ComfyUI starts, run `bash /opt/minimax-h3/download_minimax_h3_models.sh` to download and validate all models enabled for the GPU family. The five base assets plus the pinned Ref2VA Turbo 4-step LoRA total approximately 122.16 GB (113.8 GiB), before additional Seed Hunter assets, generated output, and safety reserve. Configure **at least 150 GB Container Disk**; 160 GB or more gives more practical headroom.

A 32 GB GPU does not mean the full BF16 weights fit entirely in VRAM. Actual generation depends on ComfyUI's model offload behavior, system RAM, resolution, frame count, and workflow settings. This repository does not promise that every BF16 workflow will fit a given GPU configuration.

## RunPod template

GitHub Actions builds the legacy image from `main` and the dedicated RTX 5090 image from `rtx5090-comfyui-0.42.1`:

- Ada (compute capability 8.9; RTX 40/L40/L40S): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-ada`
- Blackwell legacy image (compute capability 12.0): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-blackwell` (ComfyUI v0.34.0)
- RTX 5090 image (compute capability 12.0; ComfyUI v0.42.1): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-rtx5090-comfyui-0.42.1` (ComfyUI only)
- RTX 5090 + SGLang image (ComfyUI v0.42.1): `ghcr.io/svrmsk000/minimax-h3-bf16-runpod:cuda13-rtx5090-comfyui-0.42.1-sglang`

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
- `MINIMAX_H3_REFRESH_WORKFLOWS=1`
- `MINIMAX_H3_REFRESH_MEDIA=1`
- `ENABLE_SAGE_ATTENTION=0` (emergency opt-out; Sage is required by default)
- `SAGE_ATTENTION_RUNTIME_SMOKE=0` (skip the startup CUDA-kernel smoke test)
- `MINIMAX_H3_ENABLE_SGLANG=1` (automatically start SGLang at Pod startup; default 0)
- `SGLANG_VENV` (optional isolated SGLang virtualenv path; default `/opt/minimax-h3/sglang-venv`)
- `SGLANG_DIT_RESIDENT_LAYERS` (one-GPU default 4)
- `SGLANG_DIT_RESIDENT_LAYERS_2GPU` (two-GPU default 20)
- `SGLANG_DIT_RESIDENT_LAYERS_4GPU` (four-GPU default 20)
- `SGLANG_VIDEO_VAE_RESIDENT_LAYERS` (default 24 on 1 GPU; 36 on 2/4 GPUs; optional common override; per-profile overrides `SGLANG_VIDEO_VAE_RESIDENT_LAYERS_1GPU`, `_2GPU`, `_4GPU`)
- `SGLANG_WARMUP_RESOLUTIONS` (default `1344x768`)
- `SGLANG_WARMUP_NUM_FRAMES` (default 24)

## ComfyUI service management

ComfyUI can be controlled independently from the container shell:

```bash
service comfyui start
service comfyui stop
service comfyui restart
service comfyui status
```

The service launches the baked ComfyUI Python interpreter from `COMFY_VENV` (default `/workspace/runpod-slim/ComfyUI/.venv-cu130`) and reads additional arguments from `/workspace/runpod-slim/comfyui_args.txt`. This is how SageAttention 2's `--use-sage-attention` flag reaches ComfyUI; Blackwell SageAttention 3 is enabled through the exported `COMFY_SAGE_ATTENTION3` setting. Its log is `/tmp/comfyui.log`. If ComfyUI is already running from the RunPod startup script, `service comfyui start` adopts the existing process instead of launching a duplicate.

ComfyUI-Manager is pinned to `COMFYUI_MANAGER_COMMIT`, copied into `custom_nodes/comfyui-manager` during image build, and synchronized from the image at cold start. Its Python dependencies are installed during image build; Pod startup does not install Manager or its dependencies.

## SGLang Diffusion (RTX 5090)

The dedicated branch `sglang-rtx5090-comfyui-0.42.1` adds an optional SGLang Diffusion Ref2VA server without replacing ComfyUI 0.42.1 or its Python environment.

SGLang Diffusion is installed and import-validated in a separate virtual environment at `/opt/minimax-h3/sglang-venv` while the Docker image is being built. No SGLang package installation occurs during Pod startup. The optional `MINIMAX_H3_ENABLE_SGLANG=1` setting controls **automatic startup only**; it does not control whether the service can be managed later from the console.

Select the GPU topology explicitly inside the running Pod:

```bash
service sgmax 1 start   # one GPU
service sgmax 2 start   # two GPUs: tensor parallel 2, Ulysses 1
service sgmax 4 start   # four GPUs: tensor parallel 2, Ulysses 2
service sgmax stop      # stop the active SGLang server and all its worker processes
service sgmax status
```

The legacy `service sgmax start` form remains an alias for the one-GPU profile. Only one SGLang instance can run at a time; stop it before switching GPU topology. The stop command does not depend on the selected GPU count and stops the active service.

With `MINIMAX_H3_ENABLE_SGLANG=1`, the service starts automatically in the one-GPU profile after model setup completes. With it unset or set to `0`, ComfyUI starts alone, and you can select a profile manually at any time. Stopping SGLang does not stop ComfyUI or the Pod. The service log is at `/workspace/runpod-slim/logs/sglang.log`; the API listens on port `30010` for every profile.

All profiles use Ref2VA, memory-oriented layerwise offload, disabled Torch compile, 1344x768 warmup, and 24 warmup frames. The one-GPU profile uses four resident DiT layers and 24 resident video-VAE layers. The two- and four-GPU profiles use 20 resident DiT layers, 36 resident video-VAE layers, and one prefetch layer; the four-GPU profile additionally enables Ulysses degree 2. The multi-GPU profiles use tensor parallel size 2 and encoder parallel auto.

ComfyUI remains available on port `8188`. SGLang uses the official Hugging Face model repository ID `MiniMaxAI/MiniMax-H3` through `--model-path`; the launcher does not pass explicit paths to component weights stored in the ComfyUI workspace.

SGLang resolves the Ref2VA components from the model repository. Hugging Face may download model assets into its cache; set `HF_TOKEN` if access or rate limits require it.

The SGLang server supports one-, two-, and four-GPU Ref2VA profiles. All profiles use memory-oriented layerwise offload, disabled Torch compile, 1344x768 warmup, 24 frames, and port 30010. The one-GPU profile uses four resident DiT layers and 24 resident video-VAE layers; the two- and four-GPU profiles use 20 resident DiT layers and 36 resident video-VAE layers, one prefetch layer, tensor parallel size 2, and encoder parallel auto. The four-GPU profile uses Ulysses degree 2. Select a profile with the service commands above.

**Do not run a ComfyUI H3 generation and an SGLang generation at the same time on the same RTX 5090.** Both services are exposed for convenience, but they share one GPU.

## Preserved stack

- RunPod CUDA 13.0 base image and PyTorch CUDA 13.0
- ComfyUI v0.42.1 with native MiniMax H3 support on the RTX 5090 branch; legacy `main` remains on v0.34.0
- ComfyUI-Pixaroma H3 audio-sync nodes and the pinned `ComfyUI-MiniMaxH3-SGLang` bridge node
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
