# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v13-GIT-FIX ---

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

# --- 2. Clone Repositories ---
WORKDIR /app

# Prevent git from asking for credentials in the non-interactive docker environment.
# THIS IS THE CRITICAL FIX FOR THE ERROR: "terminal prompts disabled"
ENV GIT_TERMINAL_PROMPT=0

# Consolidate git operations into a single layer for robustness.
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull \
    && git clone https://github.com/DavG25/text-generation-webui-deep_reason.git extensions/text-generation-webui-deep_reason

# --- 3. Run the Automated Installer ---
RUN GPU_CHOICE=A INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 4. Configure Startup Flags ---
RUN echo "--listen --loader exllama2 --extensions text-generation-webui-deep_reason" > user_data/CMD_FLAGS.txt

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start_linux.sh"]
