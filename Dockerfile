# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v7-FINAL ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies (including git-lfs) ---
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

# --- 2. Install text-generation-webui and its dependencies ---
# Clone the repository and set the working directory
RUN git clone https://github.com/oobabooga/text-generation-webui.git /app
WORKDIR /app

# Initialize LFS and pull the large files to fix the missing requirements file
RUN git lfs install && git lfs pull

# Install all requirements from the main file first
RUN python3 -m pip install -r requirements.txt

# Install the correct stable PyTorch for CUDA 12.8
RUN python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# --- 3. Setup Persistence for Models ---
# Create a symlink so models in /workspace/models are available inside the app
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 4. Copy Startup Script ---
COPY start.sh .
RUN chmod +x start.sh

# --- 5. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start.sh"]
