#!/bin/bash
# TGW RUN.SH - V2.3 with Case-Insensitive and Robust Checks

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /opt/conda/etc/profile.d/conda.sh
conda activate /opt/conda/envs/textgen

# --- 2. Idle Timeout Functionality ---
# Default to 20 minutes (1200s) if not set. Now checks for IDLE_TIMEOUT_SECONDS as well.
IDLE_TIMEOUT_VAL=${IDLE_TIMEOUT:-${IDLE_TIMEOUT_SECONDS:-1200}}
CHECK_INTERVAL=60
LAST_ACTIVE_TIME=$(date +%s)
API_PORT=7860

function check_idle() {
    while true; do
        sleep $CHECK_INTERVAL
        if ss -tn state established '( dport = :'"$API_PORT"' or sport = :'"$API_PORT"' )' | grep -q -v '127.0.0.1'; then
            LAST_ACTIVE_TIME=$(date +%s)
        else
            CURRENT_TIME=$(date +%s)
            IDLE_DURATION=$((CURRENT_TIME - LAST_ACTIVE_TIME))
            if [ "$IDLE_DURATION" -ge "$IDLE_TIMEOUT_VAL" ]; then
                echo "--- No external connections for $IDLE_TIMEOUT_VAL seconds. Shutting down. ---"
                kill -SIGTERM 1
                exit 0
            fi
        fi
    done
}

check_idle &

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
