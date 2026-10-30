# MiniMax H3 RunPod — BF16 Ref2VA

A RunPod + ComfyUI deployment based on [Nightfall93/runpod-comfyui-minimax-h3](https://github.com/Nightfall93/runpod-comfyui-minimax-h3), adapted to use the full BF16 MiniMax H3 Ref2VA diffusion model.

## Model configuration

- Ref2VA: `minimax_h3_ref2va_bf16.safetensors` (full BF16, 66,280,487,368 bytes)
- FL2VA: retain the upstream pruned INT8 ConvRot model and workflows.
- Text encoder: retain the upstream Qwen3-VL-32B NVFP4-AWQ model.
- Video and audio VAEs: retain upstream configuration.

The BF16 Ref2VA weights are downloaded at Pod startup; they are not included in the Docker image.

## Upstream

This project is based on Nightfall93's RunPod ComfyUI MiniMax H3 project, with permission from the upstream author. Existing components and workflows are retained where compatible, with Ref2VA model references and validation updated for BF16.

Upstream: https://github.com/Nightfall93/runpod-comfyui-minimax-h3
