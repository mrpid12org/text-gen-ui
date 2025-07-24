#!/bin/bash
# TGW RUN.SH v36 - Final: Bypass launcher and run python directly.

echo "----- Starting final run.sh at $(date) -----"

# Activate the python virtual environment created by the installer
source /app/installer_files/env/bin/activate

# Build the argument list directly for the python server
# We are providing every necessary argument here.
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

echo "Activating venv and running python server.py with args: ${CMD_ARGS_ARRAY[@]}"
echo "---------------------------------"

# --- Launch Server Directly ---
# This bypasses start_linux.sh and gives us direct control.
cd /app
python server.py "${CMD_ARGS_ARRAY[@]}"
