#!/bin/bash
# TGW RUN.SH v32 - Simplified to work with CMD_FLAGS.txt

LOGFILE="/app/run.log"
echo "----- Starting run.sh at $(date) -----" | tee $LOGFILE

# Start with a base set of dynamic arguments.
# Network args are now in CMD_FLAGS.txt and will be loaded automatically.
CMD_ARGS_ARRAY=()
CMD_ARGS_ARRAY+=(--extensions deep_reason api)

# Optional multimodal extension
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
  echo "Multimodal extension enabled." | tee -a $LOGFILE
  CMD_ARGS_ARRAY+=(multimodal)
fi

# Function to find a GGUF model
find_gguf_model() {
  find /workspace/models -maxdepth 1 -type f -name '*.gguf' -print0 | {
    local files=()
    while IFS= read -r -d $'\0' file; do
      files+=("$file")
    done
    
    if [ ${#files[@]} -eq 1 ]; then
      echo "${files[0]}"
    elif [ ${#files[@]} -gt 1 ]; then
      ls -1t "${files[@]}" | head -n1
    fi
  }
}

# Model selection logic
if [ -z "$MODEL_NAME" ] && [ -n "$DEFAULT_MODEL_NAME" ]; then
  MODEL_NAME="$DEFAULT_MODEL_NAME"
fi

if [ -z "$MODEL_NAME" ]; then
  MODEL_PATH=$(find_gguf_model)
  if [ -n "$MODEL_PATH" ]; then
    MODEL_NAME=$(basename "$MODEL_PATH")
    echo "Auto-detected model: $MODEL_NAME" | tee -a $LOGFILE
  fi
fi

# If a model is specified (either by env var or auto-detect), add it to args
if [ -n "$MODEL_NAME" ]; then
  echo "Using model: $MODEL_NAME" | tee -a $LOGFILE
  CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
  CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
  fi
else
  # Auto-download fallback if enabled and no other model was found
  if [ "$AUTO_DOWNLOAD" == "true" ]; then
    FALLBACK_MODEL="mlabonne_gemma-3-27b-it-abliterated-Q5_K_L.gguf"
    FALLBACK_HF_REPO="bartowski/mlabonne_gemma-3-27b-it-abliterated-GGUF"
    if [ ! -f "/workspace/models/$FALLBACK_MODEL" ]; then
      echo "No model found, downloading fallback model..." | tee -a $LOGFILE
      huggingface-cli download "$FALLBACK_HF_REPO" "$FALLBACK_MODEL" --local-dir /workspace/models --local-dir-use-symlinks False
    fi
    CMD_ARGS_ARRAY+=(--model "$FALLBACK_MODEL")
    CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
  else
    echo "No model specified or found, and auto-download is disabled." | tee -a $LOGFILE
    echo "Please specify a MODEL_NAME or place a model in /workspace/models." | tee -a $LOGFILE
    exit 1
  fi
fi

# MoE (Mixture of Experts) config
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS_ARRAY+=(--num_experts_per_token "$NUM_EXPERTS_PER_TOKEN")
fi

echo "Additional args: ${CMD_ARGS_ARRAY[@]}" | tee -a $LOGFILE
echo "---------------------------------" | tee -a $LOGFILE

# Launch the server. It will automatically read CMD_FLAGS.txt
# and combine them with the arguments provided here.
cd /app
./start_linux.sh "${CMD_ARGS_ARRAY[@]}" 2>&1 | tee -a $LOGFILE
