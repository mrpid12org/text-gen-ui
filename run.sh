#!/bin/bash
# TGW RUN.SH v37 - Correcting python path and removing venv activation.

echo "----- Starting final run.sh at $(date) -----"

# This script no longer activates a venv, as one is not created.
# We will call the specific python version we installed in the Dockerfile.

# Build the argument list directly for the python server
CMD_ARGS_ARRAY=()

# Network settings
CMD_ARGS_ARRAY+=(--host)
CMD_ARGS_ARRAY+=(0.0.0.0)
CMD_ARGS_ARRAY+=(--port)
CMD_ARGS_ARRAY+=(7860)

# Model settings
if [ -n "$MODEL_NAME" ]; then
  echo "Using model from environment variable: $MODEL_NAME"
  CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
  CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
  CMD_ARGS_ARRAY+=(--loader llama.cpp)
else
  echo "ERROR: No MODEL_NAME environment variable set."
  exit 1
fi

echo "Running python3.12 server.py with args: ${CMD_ARGS_ARRAY[@]}"
echo "---------------------------------"

# --- Launch Server Directly ---
# This bypasses start_linux.sh and gives us direct control.
cd /app
python3.12 server.py "${CMD_ARGS_ARRAY[@]}"
