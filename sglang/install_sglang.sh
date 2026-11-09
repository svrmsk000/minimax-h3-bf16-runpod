#!/usr/bin/env bash
set -euo pipefail

VENV="${SGLANG_VENV:-/opt/minimax-h3/sglang-venv}"
PYTHON_BIN="${SGLANG_PYTHON_BIN:-python3.12}"
INSTALL_SPEC="${SGLANG_INSTALL_SPEC:-sglang[diffusion]}"
MAX_JOBS="${SGLANG_MAX_JOBS:-2}"

if [ -x "$VENV/bin/sglang" ] && [ "${SGLANG_FORCE_INSTALL:-0}" != "1" ]; then
  if "$VENV/bin/python" -c 'import sglang' >/dev/null 2>&1; then
    echo "SGLang environment already installed: $VENV"
    exit 0
  fi
  echo "Existing SGLang environment is incomplete; repairing it."
fi

command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
  echo "FATAL: Python interpreter not found: $PYTHON_BIN" >&2
  exit 1
}

export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-12.0}"
export MAX_JOBS

if ! command -v uv >/dev/null 2>&1; then
  "$PYTHON_BIN" -m pip install --no-cache-dir --upgrade uv
fi

if [ ! -x "$VENV/bin/python" ]; then
  uv venv --python "$PYTHON_BIN" "$VENV"
fi

echo "Installing SGLang Diffusion into an isolated environment."
echo "ComfyUI's Python environment and PyTorch installation will not be modified."
uv pip install --python "$VENV/bin/python" --prerelease=allow "$INSTALL_SPEC"

"$VENV/bin/python" - <<'PY'
import importlib.metadata
import sglang
print("SGLang package:", importlib.metadata.version("sglang"))
print("SGLang import:", sglang.__file__)
PY

test -x "$VENV/bin/sglang"
echo "SGLang Diffusion installation is ready: $VENV"
