# Use CUDA 12.8 runtime image as base
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
# --- CHANGE ---
# Isolate Conda from the application directory to prevent conflicts.
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# Install system packages
RUN apt-get update && apt-get install -y \
    wget git curl vim unzip build-essential \
    python3 python3-pip python3-venv \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    cmake libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# --- CHANGE ---
# Install Miniconda to the new, isolated path.
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh

# Set working directory. This is now guaranteed to be empty.
WORKDIR /app

# This command will now succeed.
RUN git clone https://github.com/oobabooga/text-generation-webui.git .

# Copy your local modifications: run.sh, requirements.txt, etc.
COPY . .

# --- CHANGE ---
# All paths now reference the new, isolated Conda environment.
# A specific environment is created to avoid polluting the base Conda install.
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
RUN conda create -y -p $TEXTGEN_ENV_DIR python=3.10 && \
    conda install -y -p $TEXTGEN_ENV_DIR pip && \
    $TEXTGEN_ENV_DIR/bin/pip install --upgrade pip

# Install Python dependencies into the new environment
RUN $TEXTGEN_ENV_DIR/bin/pip install -r requirements.txt

# Clone and build llama-cpp-python with CUDA/cuBLAS support
RUN git clone https://github.com/abetlen/llama-cpp-python.git /app/llama-cpp-python && \
    cd /app/llama-cpp-python && \
    CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 $TEXTGEN_ENV_DIR/bin/pip install .

# Patch localhost binding for llama.cpp backend
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Expose the web interface/API port
EXPOSE 7860

# Ensure entrypoint is executable
RUN chmod +x /app/run.sh

# Run the final startup script
ENTRYPOINT ["/app/run.sh"]
