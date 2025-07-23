#!/bin/bash

# Default model path (override with MODEL_NAME or MODEL_FILE)
DEFAULT_MODEL_NAME="mlabonne_gemma-3-27b-it-abliterated-Q5_K_L.gguf"
MODEL_PATH="/workspace/models/${MODEL_FILE:-$DEFAULT_MODEL_NAME}"

# Start with static flags
CMD_ARGS="--listen --extensions deep_reason,api"

# Loader logic based on file extension
if [[ "$MODEL_PATH" == *.gguf ]]; then
    CMD_ARGS="$CMD_ARGS --loader exllama2"
fi

# Add the model path
if [ -f "$MODEL_PATH" ]; then
    CMD_ARGS="$CMD_ARGS --model $(basename "$MODEL_PATH")"
else
    echo "⚠️  WARNING: Model file not found: $MODEL_PATH"
    echo "🔍 Available files in /workspace/models:"
    ls -lh /workspace/models
    echo "💥 Exiting due to missing model..."
    exit 1
fi

# Add MoE params if available
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
    CMD_ARGS="$CMD_ARGS --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

# Log flags
echo "-----------------------------------------"
echo "🚀 Launching Oobabooga with flags:"
echo "$CMD_ARGS"
echo "-----------------------------------------"

# Start the server
exec ./start_linux.sh $CMD_ARGS
