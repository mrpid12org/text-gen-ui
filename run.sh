#!/bin/bash

# Default base args
CMD_ARGS="--listen --extensions deep_reason,api"

# Handle model name from environment variable
if [ -n "$MODEL_NAME" ]; then
  CMD_ARGS="$CMD_ARGS --model $MODEL_NAME"
  
  # Auto-select loader based on file extension
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS="$CMD_ARGS --loader llama.cpp"
  else
    CMD_ARGS="$CMD_ARGS --loader exllama2"
  fi
else
  # Default loader if no model specified at launch
  CMD_ARGS="$CMD_ARGS --loader exllama2"
fi

# Optional: control MoE routing via environment variable
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS="$CMD_ARGS --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

echo "-----------------------------------------"
echo "Launching Oobabooga with the following flags:"
echo "$CMD_ARGS"
echo "-----------------------------------------"

# Start the server by calling the official startup script with our assembled flags
exec ./start_linux.sh $CMD_ARGS
