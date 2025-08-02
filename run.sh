#!/bin/bash
# TGW RUN.SH - V2.2 with Improved Idle Timeout

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. Idle Timeout Functionality ---
# Default to 20 minutes if not set
IDLE_TIMEOUT=${IDLE_TIMEOUT:-1200}
CHECK_INTERVAL=60
LAST_ACTIVE_TIME=$(date +%s)
API_PORT=7860 # Web UI's API port

function check_idle() {
    while true; do
        sleep $CHECK_INTERVAL
        
        # Check for active TCP connections, ignoring local ones from the proxy.
        # We now check if there is any established connection that is NOT from 127.0.0.1.
        if ss -tn state established '( dport = :'"$API_PORT"' or sport = :'"$API_PORT"' )' | grep -q -v '127.0.0.1'; then
            # If an external connection is found, update the last active time
            LAST_ACTIVE_TIME=$(date +%s)
            # Uncomment the line below for debugging to see when activity is detected
            # echo "Activity detected at $(date). Resetting idle timer."
        else
            # If no external connections, check how long it's been since the last one.
            CURRENT_TIME=$(date +%s)
            IDLE_DURATION=$((CURRENT_TIME - LAST_ACTIVE_TIME))

            if [ "$IDLE_DURATION" -ge "$IDLE_TIMEOUT" ]; then
                echo "--- No external connections for $IDLE_TIMEOUT seconds. Shutting down. ---"
                # This command is specific to RunPod to terminate the pod
                kill -SIGTERM 1
                exit 0
            fi
        fi
    done
}

# Start the idle checker in the background
check_idle &

# --- 3. Build Argument Array ---
CMD_ARGS_ARRAY=()

# --- Model Selection & Loader ---
if [ -n "$MODEL_NAME" ]; then
    echo "Using model from environment variable: $MODEL_NAME"
    CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
    CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
else
    echo "ERROR: No MODEL_NAME environment variable set. Cannot start."
    exit 1
fi

# --- Extensions ---
BASE_EXTENSIONS="deep_reason,api"
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
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
