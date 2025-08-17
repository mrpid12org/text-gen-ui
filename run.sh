#!/bin/bash
# TGW RUN.SH - V13.0 with Symlink Persistence & GPU Idle Shutdown for RunPod

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. Setup Persistent Storage ---
PERSISTENT_DATA_DIR="/workspace/webui-data"
echo "--- Consolidating all data into $PERSISTENT_DATA_DIR ---"

# --- Symlink the User Data Directory ---
# All user data (characters, presets, models, loras, etc.) is within 'user_data'.
USER_DATA_APP_DIR="/app/user_data"
USER_DATA_PERSISTENT_DIR="$PERSISTENT_DATA_DIR/user_data"

echo "Processing symlink: $USER_DATA_APP_DIR -> $USER_DATA_PERSISTENT_DIR"

# Ensure the target persistent directory exists
mkdir -p "$USER_DATA_PERSISTENT_DIR"

# If the original app directory exists and is NOT a symlink, move its contents
if [ -d "$USER_DATA_APP_DIR" ] && [ ! -L "$USER_DATA_APP_DIR" ]; then
    echo "Moving initial contents of $USER_DATA_APP_DIR to persistent storage..."
    rsync -a --remove-source-files "$USER_DATA_APP_DIR/" "$USER_DATA_PERSISTENT_DIR/"
    rm -rf "$USER_DATA_APP_DIR"
fi

# Ensure parent directory for the symlink exists in /app
mkdir -p "$(dirname "$USER_DATA_APP_DIR")"

# If the symlink doesn't exist, create it.
if [ ! -e "$USER_DATA_APP_DIR" ]; then
    ln -s "$USER_DATA_PERSISTENT_DIR" "$USER_DATA_APP_DIR"
    echo "Symlinked $USER_DATA_APP_DIR -> $USER_DATA_PERSISTENT_DIR"
fi

# Explicitly create the models and loras directories inside the persistent user_data folder
mkdir -p "$USER_DATA_PERSISTENT_DIR/models"
mkdir -p "$USER_DATA_PERSISTENT_DIR/loras"

echo "--- Persistence setup complete ---"


# --- 3. GPU Idle Check Functionality for RunPod ---
# (This section is unchanged from the original file)
IDLE_TIMEOUT_SECONDS=${IDLE_TIMEOUT_SECONDS:-1200}
CHECK_INTERVAL=60
GPU_UTILIZATION_THRESHOLD=10

function gpu_idle_check() {
    if [ -z "$RUNPOD_POD_ID" ]; then return; fi
    if ! command -v nvidia-smi &> /dev/null; then return; fi
    if ! command -v runpodctl &> /dev/null; then return; fi

    echo "--- GPU Idle Shutdown Enabled ---"
    LAST_ACTIVE_TIME=$(date +%s)
    while true; do
        sleep $CHECK_INTERVAL
        CURRENT_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | sort -nr | head -n1 | sed 's/[^0-9]*//g')
        if [[ "$CURRENT_UTILIZATION" -gt "$GPU_UTILIZATION_THRESHOLD" ]]; then
            LAST_ACTIVE_TIME=$(date +%s)
        else
            IDLE_DURATION=$(( $(date +%s) - LAST_ACTIVE_TIME))
            if [ "$IDLE_DURATION" -ge "$IDLE_TIMEOUT_SECONDS" ]; then
                echo "--- SHUTDOWN: GPU idle for $IDLE_DURATION seconds. Terminating pod. ---"
                runpodctl remove pod $RUNPOD_POD_ID
                exit 0
            fi
        fi
    done
}

gpu_idle_check &

# --- 4. Build Argument Array ---
# Set Gradio's temp directory to be inside the container to avoid symlink issues
export GRADIO_TEMP_DIR=/tmp/gradio

CMD_ARGS_ARRAY=()
# Point to the models and loras directories inside the persistent user_data folder
MODELS_DIR="$PERSISTENT_DATA_DIR/user_data/models"
LORAS_DIR="$PERSISTENT_DATA_DIR/user_data/loras"

# --- Model & LoRA Configuration ---
# Use explicit arguments to point the application directly to persistent storage
CMD_ARGS_ARRAY+=(--model-dir "$MODELS_DIR")
CMD_ARGS_ARRAY+=(--lora-dir "$LORAS_DIR")

if [ -n "$MODEL_NAME" ]; then
    CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
fi

# You can now also specify LoRAs to load at startup via a RunPod environment variable
if [ -n "$LORA_NAMES" ]; then
    CMD_ARGS_ARRAY+=(--lora $LORA_NAMES)
fi

CMD_ARGS_ARRAY+=(--loader llama.cpp)

# --- Extensions ---
BASE_EXTENSIONS="deep_reason,api"
if [ "${ENABLE_MULTIMODAL,,}" == "true" ]; then
    FINAL_EXTENSIONS="$BASE_EXTENSIONS,multimodal"
else
    FINAL_EXTENSIONS="$BASE_EXTENSIONS"
fi
CMD_ARGS_ARRAY+=(--extensions "$FINAL_EXTENSIONS")

# --- Optional MoE config ---
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
    CMD_ARGS_ARRAY+=(--num_experts_per_token "$NUM_EXPERTS_PER_TOKEN")
fi

# --- Networking ---
CMD_ARGS_ARRAY+=(--listen)
CMD_ARGS_ARRAY+=(--listen-host 0.0.0.0)
CMD_ARGS_ARRAY+=(--listen-port 7860)

echo "Conda env activated. Running python server.py with args: ${CMD_ARGS_ARRAY[@]}"
echo "---------------------------------"

# --- 5. Launch Server Directly ---
cd /app
python server.py "${CMD_ARGS_ARRAY[@]}"
