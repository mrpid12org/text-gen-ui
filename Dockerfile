# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v40-FINAL ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
# We only need basic tools; start_linux.sh will install Conda and Python.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    git-lfs \
    build-essential

# --- 2. Clone Main Repo & Your Custom Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git .
COPY deep_reason/ /app/extensions/deep_reason/

# --- 3. Run Installer & Install Custom Wheel ---
# This single RUN command ensures everything is installed inside the Conda environment.
RUN \
  # First, run the official installer to create the Conda env
  ./start_linux.sh && \
  \
  # Next, activate the Conda environment that was just created
  source /app/installer_files/conda/etc/profile.d/conda.sh && \
  conda activate /app/installer_files/env && \
  \
  # Now, install the high-performance ExLlama2 wheel into that active environment
  echo "Installing ExLlama2 wheel..." && \
  python -c "\
from huggingface_hub import hf_hub_download; \
whl_path = hf_hub_download(repo_id='Alissonerdx/exllamav2-0.2.7-cu12.8.0.torch2.7.0-cp312-cp312-linux_x86_64', \
filename='exllamav2-0.2.7+cu12.8.0.torch2.7.0-cp312-cp312-linux_x86_64.whl'); \
import subprocess; \
subprocess.run(['pip', 'install', '--no-cache-dir', whl_path], check=True)"

# --- 4. Setup Persistence for Models ---
RUN mkdir -p /workspace/models && rm -rf /app/models && ln -s /workspace/models /app/models

# --- 5. Copy run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
