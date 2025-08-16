#!/bin/bash
# TGW RUN.SH - V4.0 with Persistent Storage & GPU Idle Shutdown

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. GPU Idle Check Functionality for RunPod ---
# (This section is unchanged)
IDLE_TIMEOUT_SECONDS=${IDLE_TIMEOUT_SECONDS:-1200}
CHECK_INTERVAL=60
GPU_UTILIZATION_THRESHOLD=10

function gpu_idle_check() {
    if [ -z "$RUNPOD_POD_ID" ]; then
        echo "--- WARNING: RUNPOD_POD_ID not found. Disabling automatic shutdown. ---"
        return
    fi
    if ! command -v nvidia-smi &> /dev/null; then
        echo "--- WARNING: nvidia-smi not found. Disabling automatic shutdown. ---"
        return
    fi
    if ! command -v runpodctl &> /dev/null; then
        echo "--- WARNING: runpodctl not found. Disabling automatic shutdown. ---"
        return
    fi

    echo "--- GPU Idle Shutdown Enabled ---"
    echo "Timeout: ${IDLE_TIMEOUT_SECONDS}s | Check Interval: ${CHECK_INTERVAL}s | Activity Threshold: ${GPU_UTILIZATION_THRESHOLD}% GPU Utilization"

    LAST_ACTIVE_TIME=$(date +%s)
    while true; do
        sleep $CHECK_INTERVAL
        CURRENT_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | sort -nr | head -n1 | sed 's/[^0-9]*//g')
        if [[ "$CURRENT_UTILIZATION" -gt "$GPU_UTILIZATION_THRESHOLD" ]]; then
            LAST_ACTIVE_TIME=$(date +%s)
        else
            CURRENT_TIME=$(date +%s)
            IDLE_DURATION=$((CURRENT_TIME - LAST_ACTIVE_TIME))
            if [ "$IDLE_DURATION" -ge "$IDLE_TIMEOUT_SECONDS" ]; then
                echo "--- SHUTDOWN: GPU has been idle for $IDLE_DURATION seconds. Terminating pod. ---"
                runpodctl remove pod $RUNPOD_POD_ID
                exit 0
            fi
        fi
    done
}

gpu_idle_check &

# --- 3. Setup Persistent Storage Directories ---
PERSISTENT_DATA_DIR="/workspace/webui-data"
echo "--- Ensuring persistent data directories exist at $PERSISTENT_DATA_DIR ---"
mkdir -p "$PERSISTENT_DATA_DIR/characters"
mkdir -p "$PERSISTENT_DATA_DIR/instruction-templates"
mkdir -p "$PERSISTENT_DATA_DIR/presets"
mkdir -p "$PERSISTENT_DATA_DIR/loras"
mkdir -p "$PERSISTENT_DATA_DIR/logs"
mkdir -p "$PERSISTENT_DATA_DIR/prompts"

# --- 4. Build Argument Array ---
CMD_ARGS_ARRAY=()

# --- Model Selection & Loader ---
if [ -n "$MODEL_NAME" ]; then
    CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
    CMD_ARGS_ARRAY+=(--model-dir /workspace/models) # Models are in their own persistent volume
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
else
    echo "ERROR: No MODEL_NAME environment variable set. Cannot start."
    exit 1
fi

# --- NEW: Add Flags for Persistent Storage ---
CMD_ARGS_ARRAY+=(--character-dir "$PERSISTENT_DATA_DIR/characters")
CMD_ARGS_ARRAY+=(--instruction-template-dir "$PERSISTENT_DATA_DIR/instruction-templates")
CMD_ARGS_ARRAY+=(--presets-dir "$PERSISTENT_DATA_DIR/presets")
CMD_ARGS_ARRAY+=(--lora-dir "$PERSISTENT_DATA_DIR/loras")
CMD_ARGS_ARRAY+=(--logs-dir "$PERSISTENT_DATA_DIR/logs")
CMD_ARGS_ARRAY+=(--prompt-dir "$PERSISTENT_DATA_DIR/prompts")

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
