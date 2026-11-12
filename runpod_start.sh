#!/usr/bin/env bash
set -euo pipefail

# MiniMax H3 replacement for the upstream RunPod /start.sh.
# All software is baked into the image. This script only configures and starts
# services; it must never create Python environments or install packages.

COMFYUI_ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
FILEBROWSER_DB="/workspace/runpod-slim/filebrowser.db"

echo "=== MiniMax H3 RunPod services startup (no software installation) ==="

# SSH: retain the RunPod image's access behavior without installing anything.
mkdir -p /run/sshd /root/.ssh
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -A -q
fi
if [ -n "${PUBLIC_KEY:-}" ]; then
  touch /root/.ssh/authorized_keys
  grep -Fqx -- "$PUBLIC_KEY" /root/.ssh/authorized_keys || printf '%s\n' "$PUBLIC_KEY" >> /root/.ssh/authorized_keys
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
else
  random_password="$(openssl rand -base64 12)"
  echo "root:${random_password}" | chpasswd
  echo "Generated random SSH password for root: ${random_password}"
fi
grep -Fqx 'PermitUserEnvironment yes' /etc/ssh/sshd_config || echo 'PermitUserEnvironment yes' >> /etc/ssh/sshd_config
/usr/sbin/sshd

# Preserve RunPod environment variables for SSH login shells.
ENV_FILE="/etc/environment"
PAM_ENV_FILE="/etc/security/pam_env.conf"
SSH_ENV_FILE="/root/.ssh/environment"
touch "$ENV_FILE" "$PAM_ENV_FILE"
: > "$SSH_ENV_FILE"
: > /etc/rp_environment
while IFS= read -r env_line; do
  case "$env_line" in
    RUNPOD_*=*|PATH=*|_=*|CUDA*=*|LD_LIBRARY_PATH=*|PYTHONPATH=*|PIP_CONSTRAINT=*)
      env_name="${env_line%%=*}"
      env_value="${env_line#*=}"
      printf '%s="%s"\n' "$env_name" "$env_value" >> "$ENV_FILE"
      printf '%s DEFAULT="%s"\n' "$env_name" "$env_value" >> "$PAM_ENV_FILE"
      printf '%s="%s"\n' "$env_name" "$env_value" >> "$SSH_ENV_FILE"
      printf 'export %s="%s"\n' "$env_name" "$env_value" >> /etc/rp_environment
      ;;
  esac
done < <(printenv)
grep -Fqx 'source /etc/rp_environment' /root/.bashrc 2>/dev/null || echo 'source /etc/rp_environment' >> /root/.bashrc
grep -Fqx 'source /etc/rp_environment' /etc/bash.bashrc 2>/dev/null || echo 'source /etc/rp_environment' >> /etc/bash.bashrc
chmod 644 "$ENV_FILE" "$PAM_ENV_FILE"
chmod 600 "$SSH_ENV_FILE"

# FileBrowser is already installed in the base image; initialize its database
# only when absent, then start the preinstalled binary.
if [ ! -f "$FILEBROWSER_DB" ]; then
  echo "Initializing FileBrowser..."
  filebrowser config init
  filebrowser config set --address 0.0.0.0
  filebrowser config set --port 8080
  filebrowser config set --root /workspace
  filebrowser config set --auth.method=json
  filebrowser users add "${FILEBROWSER_USERNAME:-admin}" "${FILEBROWSER_PASSWORD:-adminadmin12}" --perm.admin
else
  echo "Using existing FileBrowser configuration..."
fi
echo "Starting FileBrowser on port 8080..."
nohup filebrowser &> /filebrowser.log &

# JupyterLab is already installed in the base image.
mkdir -p /workspace
echo "Starting JupyterLab on port 8888..."
nohup jupyter lab \
  --allow-root \
  --no-browser \
  --port=8888 \
  --ip=0.0.0.0 \
  --FileContentsManager.delete_to_trash=False \
  --FileContentsManager.preferred_dir=/workspace \
  --ServerApp.root_dir=/workspace \
  --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
  --IdentityProvider.token="${JUPYTER_PASSWORD:-}" \
  --ServerApp.allow_origin=* &> /jupyter.log &

# The MiniMax H3 setup has already copied the baked ComfyUI tree and relocated
# the baked venv. Do not create a venv, run pip, or launch main.py here.
if [ ! -f "$COMFYUI_ARGS_FILE" ]; then
  printf '%s\n' '# Add your custom ComfyUI arguments here (one per line)' > "$COMFYUI_ARGS_FILE"
fi
test -f /workspace/runpod-slim/ComfyUI/main.py
test -x /workspace/runpod-slim/ComfyUI/.venv-cu130/bin/python
test -x /etc/init.d/comfyui
echo "Starting ComfyUI only through the image-managed service..."
service comfyui start

shutdown_services() {
  echo "Stopping MiniMax H3 services..."
  service comfyui stop || true
  if [ "${MINIMAX_H3_ENABLE_SGLANG:-0}" = "1" ]; then service sgmax 1 stop || true; fi
  pkill -TERM -f 'jupyter-lab' 2>/dev/null || true
  pkill -TERM -x filebrowser 2>/dev/null || true
  pkill -TERM -x sshd 2>/dev/null || true
  exit 0
}
trap shutdown_services TERM INT

# Keep PID 1 alive while allowing Docker stop signals to run cleanup.
while true; do
  sleep 3600 &
  wait "$!" || true
done
