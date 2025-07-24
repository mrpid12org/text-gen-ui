# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v26-EXLLAMA2-PY312-FIX-HF-DOWNLOAD ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    aria2 \
    wget \
    build-essential \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 2. Upgrade pip and install huggingface_hub explicitly for python3.12 ---
RUN python3.12 -m pip install --upgrade pip setuptools wheel huggingface_hub

# --- 3. Clone Main Repo & Copy Local Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull
COPY deep_reason/ /app/extensions/deep_reason/

# --- 4. Run the Automated Installer ---
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 4b. Patch ExLlama2 for CUDA 12.8 + Torch 2.7 by downloading wheel with huggingface_hub ---
RUN python3.12 -c "\
from huggingface_hub import hf_hub_download; \
whl_path = hf_hub_download(repo_id='Alissonerdx/exllamav2-0.2.7-cu12.8.0.torch2.7.0-cp312-cp312-linux_x86_64', \
filename='exllamav2-0.2.7+cu12.8.0.torch2.7.0-cp312-cp312-linux_x86_64.whl'); \
import subprocess; subprocess.run(['python3.12', '-m', 'pip', 'install', '--no-cache-dir', whl_path], check=True)"

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Copy updated run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 7. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
