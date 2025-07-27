# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v49-FINAL ---

# --- 1. Set Environment ---
ENV DEBIAN_FRONTEND=noninteractive

# --- 2. Switch to Bash Shell ---
SHELL ["/bin/bash", "-c"]

# --- 3. Install System Dependencies ---
RUN rm -f /etc/apt/sources.list.d/cuda*.list && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    git-lfs \
    build-essential

# --- 4. Clone Main Repo & Your Custom Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git .
COPY deep_reason/ /app/extensions/deep_reason/

# --- 5. Run Installer & Install Custom Wheel ---
RUN \
  GPU_CHOICE=E LAUNCH_AFTER_INSTALL=FALSE ./start_linux.sh && \
  source /app/installer_files/conda/etc/profile.d/conda.sh && \
  conda activate /app/installer_files/env && \
  echo "Installing ExLlama2..." && \
  pip install exllamav2

# --- 6. Patch the Source Code ---
# This is the definitive fix: change the hard-coded localhost address in the correct file.
RUN sed -i "s/self.host = '127.0.0.1'/self.host = '0.0.0.0'/" modules/llama_cpp_server.py

# --- 7. Setup Persistence for Models ---
RUN mkdir -p /workspace/models && rm -rf /app/models && ln -s /workspace/models /app/models

# --- 8. Copy run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 9. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
