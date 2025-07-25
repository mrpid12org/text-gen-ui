#!/bin/bash
# TGW RUN.SH v47 - Simplified for patched Dockerfile

echo "----- Starting final run.sh at $(date) -----"

# --- 1. Activate Conda Environment ---
source /app/installer_files/conda/etc/profile.d/conda.sh
conda activate /app/installer_files/env

# --- 2. Build Argument Array ---
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

# Add the --nowebui flag to ensure the llama.cpp server is used
CMD_ARGS_ARRAY+=(--nowebui)

echo "Conda env activated. Running python server.py with args: ${CMD_ARGS_ARRAY[@]}"
echo "---------------------------------"

# --- 3. Launch Server Directly ---
cd /app
python server.py "${CMD_ARGS_ARRAY[@]}"
