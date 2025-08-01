# Dockerfile - V6.5 (Development Version)
# This version prioritizes granular caching for faster debugging.
# RUN commands are kept separate to leverage Docker's layer caching during development.

# =================================================================================================
# STAGE 1: The "Builder" - For compiling the application on a build server (e.g., GitHub Actions)
# =================================================================================================
# Use a specific 'devel' image with the full CUDA toolkit for compilation.
# For maximum reproducibility, consider pinning this to a specific SHA digest.
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

# Set environment variables for a non-interactive setup and define key paths.
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV PATH=$CONDA_DIR/bin:/usr/local/cuda/bin:$PATH

# --- System Dependencies ---
# Install all build-time system dependencies in a single layer to reduce image size.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget git curl vim unzip build-essential \
    python3 python3-pip \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    cmake libopenblas-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# --- Miniconda Installation ---
# Install Miniconda, accept ToS, and clean up in a single RUN command.
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    conda config --set auto_update_conda false && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/r && \
    conda clean -afy

# Set the working directory for the application.
WORKDIR /app

# --- Application Code & Setup ---
# Clone the web UI repository. The '.' clones it into the current WORKDIR.
RUN git clone https://github.com/oobabooga/text-generation-webui.git .

# Copy your custom files into the correct locations within the build context.
COPY run.sh .
COPY extra-requirements.txt .
COPY deep_reason ./extensions/deep_reason

# --- Python Environment & Dependencies ---
# Create the Conda environment and install dependencies in separate layers for caching.
RUN conda create -y -p $TEXTGEN_ENV_DIR python=3.11
RUN conda install -y -p $TEXTGEN_ENV_DIR pip
RUN $TEXTGEN_ENV_DIR/bin/pip install --upgrade pip

# Install dependencies from the requirements file for CUDA 12.8
RUN $TEXTGEN_ENV_DIR/bin/pip install -r requirements/full/requirements_cuda128.txt

# Install your project-specific extra dependencies
RUN $TEXTGEN_ENV_DIR/bin/pip install -r extra-requirements.txt

# --- THE WERKZEUG HOTFIX ---
# The main requirements file can install a version of Werkzeug that conflicts with other
# dependencies. Reinstalling a known compatible version (2.3.x) at the end resolves this.
RUN $TEXTGEN_ENV_DIR/bin/pip install --force-reinstall Werkzeug==2.3.8

# --- CUDA-Specific Compilation ---
# Create a symbolic link to the CUDA stub library. This is required for the linker to find
# the necessary CUDA libraries during the compilation of llama-cpp-python.
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/libcuda.so.1

# Install llama-cpp-python with CUDA support.
# CMAKE_ARGS tells cmake to build with CUDA support for specific GPU architectures.
# (e.g., 80=A100, 89=RTX30xx, 100=H100). Adjust if you use different hardware.
RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;89;100" \
    $TEXTGEN_ENV_DIR/bin/pip install llama-cpp-python --no-cache-dir

# =================================================================================================
# STAGE 2: The "Final" Image - For running the application on a GPU host (e.g., RunPod)
# =================================================================================================
# Start from the leaner 'base' image which only contains the CUDA runtime, not the full toolkit.
FROM nvidia/cuda:12.8.0-base-ubuntu22.04

# --- Environment Setup ---
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV PATH=$TEXTGEN_ENV_DIR/bin:$CONDA_DIR/bin:$PATH

# Set NVIDIA container runtime variables to ensure the container has access to the host's GPU.
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# --- Runtime Dependencies ---
# Install only the essential shared libraries required for the application to run.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    libopenblas-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory.
WORKDIR /app

# --- Copy from Builder ---
# Copy the fully configured Conda environment (with all packages) from the builder stage.
COPY --from=builder $CONDA_DIR $CONDA_DIR
# Copy the application code and your custom files from the builder stage.
COPY --from=builder /app /app

# --- Final Configuration ---
# Patch the llama.cpp backend to listen on all network interfaces (0.0.0.0),
# which is necessary for it to be accessible from outside the container in RunPod.
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py

# Expose the port for the web UI and API.
EXPOSE 7860

# Make the entrypoint script executable.
RUN chmod +x /app/run.sh

# Set the final startup script to run when the container starts.
ENTRYPOINT ["/app/run.sh"]
