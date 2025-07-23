# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v23-AUTO-DETECT ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
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

# --- 2. Install huggingface_hub CLI for downloads ---
RUN python3 -m pip install --no-cache-dir huggingface_hub

# --- 3. Clone Main Repo & Copy Local Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull
COPY deep_reason/ /app/extensions/deep_reason/

# --- 4. Run the Automated Installer ---
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Copy updated run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 7. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
