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
    $TEXTGEN_ENV_DIR/bin/pip install --upgrade pip

# Install from the specific CUDA 12.8 requirements file, then your extras
RUN $TEXTGEN_ENV_DIR/bin/pip install -r requirements/full/requirements_cuda128.txt
RUN $TEXTGEN_ENV_DIR/bin/pip install -r extra-requirements.txt

# Install llama-cpp-python, telling the linker where to find the full CUDA libraries.
RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;89;100" \
    LDFLAGS="-L/usr/local/cuda/lib64" \
    $TEXTGEN_ENV_DIR/bin/pip install llama-cpp-python --no-cache-dir

# =================================================================================================
# STAGE 2: The "Final" Image - For running on RunPod (with GPU)
# =================================================================================================
# Start from the leaner 'base' image which only contains the CUDA runtime
FROM nvidia/cuda:12.8.0-base-ubuntu22.04

# Set environment variables for the runtime
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV PATH=$TEXTGEN_ENV_DIR/bin:$CONDA_DIR/bin:$PATH

# Set NVIDIA container runtime variables to ensure GPU access on RunPod
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Install only essential RUNTIME system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    libopenblas-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the fully configured Conda environment (with all packages) from the builder stage
COPY --from=builder $CONDA_DIR $CONDA_DIR

# Copy the application code and your local files from the builder stage
COPY --from=builder /app /app

# Patch the hard-coded localhost binding for the llama.cpp backend to allow remote access
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Expose the web interface/API port
EXPOSE 7860

# Ensure the entrypoint script is executable
RUN chmod +x /app/run.sh

# Set the final startup script to run when the container starts on RunPod
ENTRYPOINT ["/app/run.sh"]
