# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v9-LAYER-FIX ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    build-essential \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 2. Clone Repository and Install Core Dependencies ---
# Combine steps into a single layer to ensure correct path context.
# This clones the repo, pulls LFS files, and installs requirements all at once.
RUN git clone https://github.com/oobabooga/text-generation-webui.git /app \
    && cd /app \
    && git lfs install \
    && git lfs pull \
    && python3 -m pip install -r requirements.txt

# Set the working directory for all subsequent commands
WORKDIR /app

# --- 3. Install PyTorch ---
RUN python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# --- 4. Install Extensions ---
# The WORKDIR is now /app, so we can use relative paths.
RUN git clone https://github.com/DavG25/text-generation-webui-deep_reason.git extensions/text-generation-webui-deep_reason
RUN python3 -m pip install -r extensions/text-generation-webui-deep_reason/requirements.txt

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Copy Startup Script ---
COPY start.sh .
RUN chmod +x start.sh

# --- 7. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start.sh"]
