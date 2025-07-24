# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v39-FINAL ---

ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install System Dependencies & Python ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common curl wget git git-lfs build-essential

# --- 2. Clone Main Repo & Custom Extensions ---
WORKDIR /app
ENV GIT_TERMINAL_PROMPT=0
RUN git clone https://github.com/oobabooga/text-generation-webui.git .
# Note: Add back your COPY command for the deep_reason extension if needed
# COPY deep_reason/ /app/extensions/deep_reason/

# --- 3. Run the Automated Installer ---
# This step creates the Conda environment at /app/installer_files/env
RUN ./start_linux.sh

# --- 4. Setup Persistence for Models ---
RUN mkdir -p /workspace/models && rm -rf /app/models && ln -s /workspace/models /app/models

# --- 5. Copy run.sh ---
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "run.sh"]
