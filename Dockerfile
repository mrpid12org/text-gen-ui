# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v41-FINAL ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    git-lfs \
    build-essential

# --- 2. Clone Main Repo & Your Custom Extension ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git .
COPY deep_reason/ /app/extensions/deep_reason/

# --- 3. Run Installer & Install Custom Wheel ---
# This single RUN command ensures everything is installed inside the Conda environment.
RUN \
  # First, run the official installer with GPU_CHOICE=E to select CUDA 12.8 non-interactively
  GPU_CHOICE=E ./start_linux.sh && \
  \
  # Next, activate the Conda environment that was just created
  source /app/installer_files/conda/etc/profile.d/conda.sh && \
  conda activate /app/installer_files/env && \
  \
  # Now, install the high-performance ExLlama2 wheel into that active environment
  echo "Installing ExLlama2..." && \
  pip install exllamav2

# --- 4. Setup Persistence for Models ---
RUN mkdir -p /workspace/models && rm -rf /app/models && ln -s /workspace/models /app/models

# --- 5. Copy run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
