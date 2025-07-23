# Use the correct NVIDIA CUDA runtime image for your hardware
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v19-BUILD-FIX ---

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

# --- 2. Clone Main Repo & Copy Local Extension ---
WORKDIR /app

# Prevent git from asking for credentials.
ENV GIT_TERMINAL_PROMPT=0

# Use the standard "git clone" method for the main repository.
RUN git clone https://github.com/oobabooga/text-generation-webui.git . \
    && git lfs pull

# Copy your local, paid extension into the correct directory inside the image.
COPY deep_reason/ /app/extensions/deep_reason/

# --- 3. Run the Automated Installer ---
# Added LAUNCH_AFTER_INSTALL=FALSE to prevent the script from hanging the build.
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=TRUE ./start_linux.sh

# --- 4. Configure Startup Flags ---
# This creates the flag file to activate the extension on startup.
RUN echo "--listen --loader exllama2 --extensions deep_reason" > user_data/CMD_FLAGS.txt

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start_linux.sh"]
