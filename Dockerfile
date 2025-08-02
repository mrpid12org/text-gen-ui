# Dockerfile - V7.0 (Production Optimized)
# This version combines RUN commands to reduce image layers and size.

# =================================================================================================
# STAGE 1: The "Builder" - For compiling the application on a build server (e.g., GitHub Actions)
# =================================================================================================
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV PATH=$CONDA_DIR/bin:/usr/local/cuda/bin:$PATH

# --- Install System & Python Dependencies ---
# Combine installations into single RUN commands to reduce layers.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget git curl vim unzip build-essential \
    python3 python3-pip \
    ca-certificates sudo software-properties-common \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    cmake libopenblas-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    conda config --set auto_update_conda false && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --channel https://repo.anaconda.com/pkgs/r && \
    conda clean -afy

WORKDIR /app

# --- Application Code & Setup ---
RUN git clone https://github.com/oobabooga/text-generation-webui.git .
COPY run.sh .
COPY extra-requirements.txt .
COPY deep_reason ./extensions/deep_reason

# --- Create Environment and Install Python Packages ---
RUN conda create -y -p $TEXTGEN_ENV_DIR python=3.11 && \
    conda install -y -p $TEXTGEN_ENV_DIR pip && \
    $TEXTGEN_ENV_DIR/bin/pip install --upgrade pip && \
    $TEXTGEN_ENV_DIR/bin/pip install -r requirements/full/requirements_cuda128.txt && \
    $TEXTGEN_ENV_DIR/bin/pip install -r extra-requirements.txt && \
    $TEXTGEN_ENV_DIR/bin/pip install --force-reinstall Werkzeug==2.3.8

# --- CUDA-Specific Compilation ---
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/libcuda.so.1

RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;89;100" \
    $TEXTGEN_ENV_DIR/bin/pip install llama-cpp-python --no-cache-dir

# =================================================================================================
# STAGE 2: The "Final" Image - For running the application on a GPU host (e.g., RunPod)
# =================================================================================================
FROM nvidia/cuda:12.8.0-base-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV PATH=$TEXTGEN_ENV_DIR/bin:$CONDA_DIR/bin:$PATH
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# --- Install Runtime Dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1-mesa-glx \
    libopenblas-dev libgomp1 iproute2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- Copy from Builder ---
COPY --from=builder $CONDA_DIR $CONDA_DIR
COPY --from=builder /app /app

# --- Final Configuration ---
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /app/modules/llama_cpp_server.py
RUN chmod +x /app/run.sh

EXPOSE 7860
ENTRYPOINT ["/app/run.sh"]
