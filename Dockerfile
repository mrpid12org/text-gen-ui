# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v22-DOWNLOAD-TOOLS ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    wget \
    aria2 \
    build-essential \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 2. Install Hugging Face CLI (for gated model downloads) ---
RUN pip install --no-cache-dir huggingface_hub && \
    git lfs install

# --- 3. Clone Main Repo & Copy Local Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull
COPY deep_reason/ /app/extensions/deep_reason/

# --- 4. Run the Automated Installer ---
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 5. Create the Custom Startup Script ---
RUN echo '#!/bin/bash' > run.sh && \
    echo '' >> run.sh && \
    echo '# Start with the static flags we always want' >> run.sh && \
    echo 'CMD_ARGS="--listen --extensions deep_reason,api"' >> run.sh && \
    echo '' >> run.sh && \
    echo '# Check for dynamic flags from environment variables and append them' >> run.sh && \
    echo 'if [ -n "$MODEL_NAME" ]; then' >> run.sh && \
    echo '  CMD_ARGS="$CMD_ARGS --model $MODEL_NAME"' >> run.sh && \
    echo '  if [[ "$MODEL_NAME" == *.gguf ]]; then' >> run.sh && \
    echo '    CMD_ARGS="$CMD_ARGS --loader exllama2"' >> run.sh && \
    echo '  fi' >> run.sh && \
    echo 'fi' >> run.sh && \
    echo '' >> run.sh && \
    echo 'if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then' >> run.sh && \
    echo '  CMD_ARGS="$CMD_ARGS --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"' >> run.sh && \
    echo 'fi' >> run.sh && \
    echo '' >> run.sh && \
    echo 'echo -----------------------------------------' >> run.sh && \
    echo 'echo "Launching Oobabooga with the following flags:"' >> run.sh && \
    echo 'echo "$CMD_ARGS"' >> run.sh && \
    echo 'echo -----------------------------------------' >> run.sh && \
    echo 'exec ./start_linux.sh $CMD_ARGS' >> run.sh && \
    chmod +x run.sh

# --- 6. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 7. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
