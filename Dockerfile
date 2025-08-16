# Dockerfile - V7.2 (Production Optimized - With Update Step)
# This version adds a git pull to ensure the latest version of the webui is always used during a build.

# =================================================================================================
# STAGE 1: The "Builder" - For compiling the application on a build server
# =================================================================================================
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV TEXTGEN_ENV_DIR=$CONDA_DIR/envs/textgen
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV PATH=$CONDA_DIR/bin:/usr/local/cuda/bin:$PATH

# --- Install System & Python Dependencies ---
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
# UPDATED: Now pulls the latest changes to get new model support
RUN git clone https://github.com/oobabooga/text-generation-webui.git . && \
    git pull

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

# Re-compiling llama-cpp-python to get the latest version
RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;89;100" \
    $TEXTGEN_ENV_DIR/bin/pip install llama-cpp-python --no-cache-dir --force-reinstall --upgrade

# =================================================================================================
# STAGE 2: The "Final" Image - For running on a GPU host
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
```

#### Step 2: Rebuild Your Docker Container

Now, in your terminal, navigate to the directory that contains your `Dockerfile` and the other build files. Then run the following command.

```bash
docker build -t text-gen-ui-updated .
```
* `docker build`: The command to build an image.
* `-t text-gen-ui-updated`: This "tags" or names your new image so you can easily identify it.
* `.`: This tells Docker to look for the `Dockerfile` in the current directory.

This process will take a while as it has to re-download the repository and reinstall all the Python packages.

#### Step 3: Run Your New Container

Once the build is complete, you will need to stop your old container and start the new, updated one. You will need to map your `/workspace/models` directory into the new container so it can see your downloaded models.

```bash
# First, find and stop your old running container
docker ps
# (Find the container ID or name from the list)
docker stop [YOUR_OLD_CONTAINER_ID_OR_NAME]

# Now, run the new, updated container
docker run -d --gpus all -p 7860:7860 -v /workspace/models:/workspace/models --name text-gen-ui text-gen-ui-updated
```
* `-v /workspace/models:/workspace/models`: This is the crucial part that links your existing models folder on the host to the `/workspace/models` folder inside the new container.

After this, you should be able to access the web UI, and the `gpt-oss-120b` model will load successful
