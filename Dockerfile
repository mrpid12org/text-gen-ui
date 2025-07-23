# --- STAGE 1: The Downloader ---
# This stage uses a lightweight image to download the source as a ZIP file, bypassing git.
FROM alpine:latest as downloader

# Install wget and unzip
RUN apk update && apk add --no-cache wget unzip

# Download the source code and extract it
WORKDIR /src
RUN wget -O text-generation-webui.zip https://github.com/oobabooga/text-generation-webui/archive/refs/heads/main.zip
RUN unzip text-generation-webui.zip && mv text-generation-webui-main /app_source


# --- STAGE 2: The Final Image ---
# Start building the main image from the correct CUDA base
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# --- DOCKERFILE VERSION: TGW-v17-SIMPLIFIED-INSTALL ---

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

# --- 2. Copy Source Code and Extensions ---
WORKDIR /app

# Copy the pre-downloaded application source from the downloader stage
COPY --from=downloader /app_source /app

# Copy your local, paid extension into the correct directory inside the image
COPY deep_reason/ /app/extensions/deep_reason/

# --- 3. Run the Automated Installer ---
# Simplified installer command. This sets up the main web UI environment.
RUN GPU_CHOICE=A ./start_linux.sh

# --- 4. Configure Startup Flags ---
# This creates the flag file to activate the extension on startup.
RUN echo "--listen --loader exllama2 --extensions deep_reason" > user_data/CMD_FLAGS.txt

# --- 5. Setup Persistence for Models ---
RUN mkdir -p /workspace/models
RUN rm -rf ./models && ln -s /workspace/models ./models

# --- 6. Expose Port and Set Entrypoint ---
EXPOSE 7860
CMD ["/bin/bash", "start_linux.sh"]
