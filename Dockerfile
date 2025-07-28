# Dockerfile - V6.2 (Final, Corrected Linker Path)
# =================================================================================================
# STAGE 1: The "Builder" - For building on GitHub Actions (no GPU)
# =================================================================================================
# Use the specified 12.8.0 'devel' image with the full CUDA toolkit for compilation.
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

# Set environment variables for non-interactive setup and paths
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV PATH=$CONDA_DIR/bin:/usr/local/cuda/bin:$PATH

# Install all build-time system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget git curl vim unzip build-essential \
    python3 python3-pip \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    cmake libopenblas-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda and accept Terms of Service
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    conda config --set auto_update_conda false && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/r && \
    conda clean -afy

# Set the working directory for the application
WORKDIR /app

# Clone the web UI repository into the current directory.
RUN git clone https://github.com/oobabooga/text-generation-webui.git .

# Copy your custom files into the correct locations
COPY run.sh .
COPY extra-requirements.txt .
COPY deep_reason ./extensions/deep_reason

# Create Conda environment with Python 3.11 and install dependencies
RUN conda create -y -p $TEXTGEN_ENV_DIR python=3.11 && \
    conda install -y -p $TEXTGEN_ENV_DIR pip && \
    $TEXTGEN_
