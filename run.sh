#!/bin/bash

set -e
set -x  # Optional: logs every line for debugging

# --- Base flags ---
CMD_ARGS="--listen --extensions deep_reason,api"

# --- Append model name if provided ---
if [ -n "$MODEL_NAME" ]; then
  CMD_ARGS="$CMD_ARGS --model $MODEL_NAME"

  # --- Detect loader based on filename ---
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS="$CMD_ARGS --loader llama.cpp"
  else
    CMD_ARGS="$CMD_ARGS --loader exllama2"
  fi
else
  echo "⚠️  WARNING: No MODEL_NAME provided. The UI will launch without loading a model."
fi

# --- Optional: pass expert flag ---
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS="$CMD_ARGS --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

# --- Launch ---
echo "-----------------------------------------"
echo "Launching Oobabooga with the following flags:"
echo "$CMD_ARGS"
echo "-----------------------------------------"

exec ./start_linux.sh $CMD_ARGS
