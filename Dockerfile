# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

# --- THIS IS THE VERSION IDENTIFIER ---
RUN echo "--- DOCKERFILE VERSION: TGW-v2-CUDA12.8-FIX ---"

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 2. Install text-generation-webui and its dependencies ---
WORKDIR /app

# Clone the repository
RUN git clone https://github.com/oobabooga/text-generation-webui.git .

# --- THIS IS THE FIX ---
# Install the correct stable PyTorch for CUDA 12.8
RUN python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Install the requirements for the exllama2 loader and the main application
RUN python3 -m pip install -r requirements_exllama2.txt
RUN python3 -m pip install -r requirements.txt

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
