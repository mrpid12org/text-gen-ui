# Use CUDA 12.8 runtime image as base
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/app/installer_files/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# Install system packages
RUN apt-get update && apt-get install -y \
    wget git curl vim unzip build-essential \
    python3 python3-pip python3-venv \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    cmake libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh

# Set working directory
WORKDIR /app

# Clone oobabooga web UI
RUN git clone https://github.com/oobabooga/text-generation-webui.git /app

# Copy your local modifications: run.sh, requirements.txt, etc.
COPY . .

# Create Conda environment and install Python + pip
RUN conda create -y -p /app/installer_files/env python=3.10 && \
    conda install -y -p /app/installer_files/env pip && \
    /app/installer_files/env/bin/pip install --upgrade pip

# Install Python dependencies
RUN /app/installer_files/env/bin/pip install -r requirements.txt

# Clone and build llama-cpp-python with CUDA/cuBLAS support
RUN git clone https://github.com/abetlen/llama-cpp-python.git /app/llama-cpp-python && \
    cd /app/llama-cpp-python && \
    CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 /app/installer_files/env/bin/pip install .

# Patch localhost binding for llama.cpp backend
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Expose the web interface/API port
EXPOSE 7860

# Ensure entrypoint is executable
RUN chmod +x /app/run.sh

# Run the final startup script
ENTRYPOINT ["/app/run.sh"]
