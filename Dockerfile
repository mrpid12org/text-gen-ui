# Dockerfile - V1.7
# Switch from the 'runtime' to the 'devel' image to include the full CUDA toolkit,
# which is required to compile llama-cpp-python with GPU support.
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

# --- FIX V1.7 ---
# Add all necessary library and binary paths to the environment. This ensures
# that the compiler and linker can find the CUDA toolkit and system libraries.
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV PATH=/usr/local/cuda/bin:$PATH
ENV DEBIAN_FRONTEND=noninteractive

# Isolate Conda from the application directory to prevent conflicts
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

# Install Miniconda to the new, isolated path
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh

# Accept Anaconda Terms of Service for the specific default channels.
RUN conda config --set auto_update_conda false && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/r

# Set working directory, which is now guaranteed to be empty
WORKDIR /app

# This command will now succeed
RUN git clone https://github.com/oobabooga/text-generation-webui.git .

# Copy your local modifications: run.sh, requirements.txt, etc.
COPY . .

# All paths now reference the new, isolated Conda environment
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
RUN conda create -y -p $TEXTGEN_ENV_DIR python=3.10 && \
    conda install -y -p $TEXTGEN_ENV_DIR pip && \
    $TEXTGEN_ENV_DIR/bin/pip install --upgrade pip

# Install Python dependencies from your requirements.txt
RUN $TEXTGEN_ENV_DIR/bin/pip install -r requirements.txt

# Clone and build llama-cpp-python with CUDA/cuBLAS support
# The build flag has been updated from LLAMA_CUBLAS to GGML_CUDA.
RUN git clone --recursive https://github.com/abetlen/llama-cpp-python.git /app/llama-cpp-python && \
    cd /app/llama-cpp-python && \
    CMAKE_ARGS="-DGGML_CUDA=on" FORCE_CMAKE=1 $TEXTGEN_ENV_DIR/bin/pip install .

# Patch the hard-coded localhost binding for the llama.cpp backend
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Expose the web interface/API port
EXPOSE 7860

# Ensure the entrypoint script is executable
RUN chmod +x /app/run.sh

# Set the final startup script to run
ENTRYPOINT ["/app/run.sh"]
