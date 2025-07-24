#!/bin/bash
# TGW RUN.SH v34 - Simplified for debugging

echo "----- Starting simplified run.sh at $(date) -----"

# We will only pass the essential model arguments.
# Network arguments are now handled by CMD_FLAGS.txt
CMD_ARGS_ARRAY=()

if [ -n "$MODEL_NAME" ]; then
  echo "Using model from environment variable: $MODEL_NAME"
  CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
  CMD_ARGS_ARRAY+=(--loader llama.cpp)
else
  echo "ERROR: No MODEL_NAME environment variable set."
  exit 1
fi

echo "Passing arguments to launcher: ${CMD_ARGS_ARRAY[@]}"
echo "---------------------------------"

# --- Launch Server ---
# The launcher will read CMD_FLAGS.txt for the network settings.
cd /app
./start_linux.sh "${CMD_ARGS_ARRAY[@]}"
