# Use the correct NVIDIA CUDA runtime image (slim base)
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v26-EXLLAMA2-FIXED-SLIM ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install system dependencies (slim + useful tools) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    aria2 \
    wget \
    build-essential \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 2. Install huggingface CLI ---
RUN pip install --no-cache-dir huggingface_hub

# --- 3. Clone WebUI and local extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull
COPY deep_reason/ /app/extensions/deep_reason/

# --- 4. Run setup script (but no launch yet) ---
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 5. Install compatible PyTorch + ExLlama2 prebuilt wheel ---
RUN pip install --upgrade pip && \
    pip install --extra-index-url https://download.pytorch.org/whl/cu121 torch==2.7.0 torchvision torchaudio && \
    pip install https://huggingface.co/Alissonerdx/exllamav2-0.2.7-cu12.8.0.torch2.7.0-cp311-cp311-linux_x86_64/resolve/main/exllamav2-0.2.7-cp311-cp311-linux_x86_64.whl

# --- 6. Persist model directory ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 7. Copy run.sh (v24) ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 8. Final setup ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
