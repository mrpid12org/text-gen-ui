#!/bin/bash
# TGW RUN.SH - V5.0 with Symlink Persistence & GPU Idle Shutdown for RunPod

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. Setup Persistent Storage via Symlinks ---
PERSISTENT_DATA_DIR="/workspace/webui-data"
echo "--- Setting up persistent storage symlinks to $PERSISTENT_DATA_DIR ---"

# List of directories inside /app to make persistent
DIRECTORIES_TO_LINK=(
    "characters"
    "instruction-templates"
    "presets"
    "loras"
    "logs"
    "prompts"
    "softprompts"
    "training/datasets"
    "training/formats"
)

for dir in "${DIRECTORIES_TO_LINK[@]}"; do
    APP_DIR="/app/$dir"
    PERSISTENT_DIR="$PERSISTENT_DATA_DIR/$dir"

    # Ensure the target persistent directory exists
    mkdir -p "$PERSISTENT_DIR"

    # If the original app directory exists and is NOT a symlink, move its contents
    if [ -d "$APP_DIR" ] && [ ! -L "$APP_DIR" ]; then
        echo "Moving initial contents of $APP_DIR to persistent storage..."
        # Use rsync to safely move contents. Handles cases where directories are empty.
        rsync -a --remove-source-files "$APP_DIR/" "$PERSISTENT_DIR/"
        rm -rf "$APP_DIR"
    fi

    # If the app directory doesn't exist (or we just removed it), create the symlink
    if [ ! -e "$APP_DIR" ]; then
        ln -s "$PERSISTENT_DIR" "$APP_DIR"
        echo "Symlinked $APP_DIR -> $PERSISTENT_DIR"
    fi
done
echo "--- Persistence setup complete ---"


# --- 3. GPU Idle Check Functionality for RunPod ---
# (This section is unchanged)
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
CMD_ARGS_ARRAY=()

# --- Model Selection & Loader ---
if [ -n "$MODEL_NAME" ]; then
    CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
    CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
else
    echo "ERROR: No MODEL_NAME environment variable set. Cannot start."
    exit 1
fi

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
