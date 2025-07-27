FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/app/installer_files/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget git curl vim unzip build-essential \
    python3 python3-pip python3-venv \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh

# Set working directory
WORKDIR /app

# Clone TGW repo and patch it
RUN git clone https://github.com/oobabooga/text-generation-webui.git /app

# Copy custom files (your model loader, run.sh, etc.)
COPY . .

# Create Conda environment and install Python packages
RUN conda create -y -p /app/installer_files/env python=3.10 && \
    conda install -y -p /app/installer_files/env pip && \
    /app/installer_files/env/bin/pip install --upgrade pip && \
    /app/installer_files/env/bin/pip install -r requirements.txt

# Critical patch for llama.cpp server binding
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Permissions
RUN chmod +x /app/run.sh

# Expose the webui port
EXPOSE 7860

# Set default entrypoint
ENTRYPOINT ["/app/run.sh"]
