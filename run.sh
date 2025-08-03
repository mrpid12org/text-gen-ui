#!/bin/bash
# TGW RUN.SH - V3.0 with GPU-based Idle Shutdown for RunPod

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. GPU Idle Check Functionality for RunPod ---
# Default to 20 minutes (1200s) if not set.
IDLE_TIMEOUT_SECONDS=${IDLE_TIMEOUT_SECONDS:-1200}
# Check every 60 seconds. A longer interval makes it less likely to shut down during brief lulls.
CHECK_INTERVAL=60
# GPU utilization must be above this threshold to be considered "active".
GPU_UTILIZATION_THRESHOLD=10

function gpu_idle_check() {
    # Sanity checks for RunPod environment
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

        # Get the highest GPU utilization across all cards.
        CURRENT_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | sort -nr | head -n1 | sed 's/[^0-9]*//g')

        if [[ "$CURRENT_UTILIZATION" -gt "$GPU_UTILIZATION_THRESHOLD" ]]; then
            # If active, just reset the timer and log it.
            LAST_ACTIVE_TIME=$(date +%s)
        else
            # If idle, check how long it's been.
            CURRENT_TIME=$(date +%s)
            IDLE_DURATION=$((CURRENT_TIME - LAST_ACTIVE_TIME))

            if [ "$IDLE_DURATION" -ge "$IDLE_TIMEOUT_SECONDS" ]; then
                echo "--- SHUTDOWN: GPU has been idle for $IDLE_DURATION seconds. Terminating pod. ---"
                # Use runpodctl to terminate the pod
                runpodctl remove pod $RUNPOD_POD_ID
                # Exit the script after sending the command
                exit 0
            fi
        fi
    done
}

# Run the idle checker in the background
gpu_idle_check &

# --- 3. Build Argument Array ---
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
# Make the check for ENABLE_MULTIMODAL case-insensitive by converting to lowercase
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

# --- 4. Launch Server Directly ---
cd /app
python server.py "${CMD_ARGS_ARRAY[@]}"
