# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v10-LFS-FIX ---

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

# --- 2. Clone Repository ---
# Use an environment variable to prevent LFS from downloading files during the initial clone.
# This ensures the directory structure is created reliably first.
ENV GIT_LFS_SKIP_SMUDGE=1
RUN git clone https://github.com/oobabooga/text-generation-webui.git /app
WORKDIR /app

# --- 3. Download LFS Files ---
# Now, pull the LFS files in a separate, dedicated step.
RUN git lfs pull

# --- 4. Install Python Requirements ---
# With the file structure now guaranteed, these commands will succeed.
RUN python3 -m pip install -r requirements.txt
RUN python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# --- 5. Install Extensions ---
RUN git clone https://github.com/DavG25/text-generation-webui-deep_reason.git extensions/text-generation-webui-deep_reason
RUN python3 -m pip install -r extensions/text-generation-webui-deep_reason/requirements.txt

# --- 6. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 7. Copy Startup Script ---
COPY start.sh .
RUN chmod +x start.sh

# --- 8. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start.sh"]
