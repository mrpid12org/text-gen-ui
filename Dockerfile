# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v44-FINAL ---

# --- 1. Set Environment ---
ENV DEBIAN_FRONTEND=noninteractive

# --- 2. Switch to Bash Shell ---
# This makes 'source' and other bash commands available.
SHELL ["/bin/bash", "-c"]

# --- 3. Install System Dependencies ---
# Added "rm -rf" to clear the apt cache and prevent mirror sync errors.
RUN rm -rf /var/lib/apt/lists/* && apt-get update && apt-get install -y --no-install-recommends \
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
  # Set env vars to make the installer non-interactive and prevent the final launch
  GPU_CHOICE=E LAUNCH_AFTER_INSTALL=FALSE ./start_linux.sh && \
  \
  # Activate the Conda environment that was just created
  source /app/installer_files/conda/etc/profile.d/conda.sh && \
  conda activate /app/installer_files/env && \
  \
  # Now, install high-performance ExLlama2 into that active environment
  echo "Installing ExLlama2..." && \
  pip install exllamav2

# --- 6. Setup Persistence for Models ---
RUN mkdir -p /workspace/models && rm -rf /app/models && ln -s /workspace/models /app/models

# --- 7. Copy run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 8. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
