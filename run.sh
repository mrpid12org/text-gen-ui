#!/bin/bash
# TGW RUN.SH v28.4 - Adds support for DEFAULT_MODEL_NAME env var + GGUF loader fix

LOGFILE="/app/run.log"
echo "----- Starting run.sh at $(date) -----" | tee $LOGFILE

CMD_ARGS="--listen --extensions deep_reason,api"

# Optional multimodal extension
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
  echo "Multimodal extension enabled." | tee -a $LOGFILE
  CMD_ARGS="${CMD_ARGS},multimodal"
fi

# Function: Auto-discover GGUF model in /workspace/models (non-recursive)
find_gguf_model() {
  echo "Looking for .gguf models in /workspace/models ..." >&2
  local files=()
  while IFS= read -r -d $'\0' file; do
    files+=("$file")
  done < <(find /workspace/models -maxdepth 1 -type f -name '*.gguf' -print0)

  if [ ${#files[@]} -eq 0 ]; then
    echo "No .gguf model files found." >&2
    return 1
  elif [ ${#files[@]} -eq 1 ]; then
    echo "Found one model: ${files[0]}" >&2
    echo "${files[0]}"
    return 0
  else
    echo "Multiple models found, picking newest by modification time:" >&2
    local latest=$(ls -1t "${files[@]}" | head -n1)
    echo "Selected: $latest" >&2
    echo "$latest"
    return 0
  fi
}

# Priority: MODEL_NAME > DEFAULT_MODEL_NAME > auto-detect > fallback
if [ -n "$MODEL_NAME" ]; then
  echo "Using MODEL_NAME from env: $MODEL_NAME" | tee -a $LOGFILE
elif [ -n "$DEFAULT_MODEL_NAME" ]; then
  echo "Using DEFAULT_MODEL_NAME from env: $DEFAULT_MODEL_NAME" | tee -a $LOGFILE
  MODEL_NAME="$DEFAULT_MODEL_NAME"
else
  MODEL_PATH=$(find_gguf_model)
  if [ $? -eq 0 ]; then
    MODEL_NAME=$(basename "$MODEL_PATH")
    echo "Auto-detected model: $MODEL_NAME" | tee -a $LOGFILE
  else
    echo "No model specified and no local model found." | tee -a $LOGFILE
    MODEL_NAME=""
  fi
fi

# Hard fallback default
FALLBACK_MODEL="mlabonne_gemma-3-27b-it-abliterated-Q5_K_L.gguf"
FALLBACK_HF_REPO="bartowski/mlabonne_gemma-3-27b-it-abliterated-GGUF"

download_model() {
  local model_file="$1"
  local hf_repo="$2"
  echo "Attempting to download $model_file from HF repo $hf_repo ..." | tee -a $LOGFILE

  if [ -n "$HF_TOKEN" ]; then
    echo "Using huggingface-cli with HF_TOKEN" | tee -a $LOGFILE
    huggingface-cli login --token "$HF_TOKEN" 2>>$LOGFILE
    huggingface-cli repo download "$hf_repo" --filename "$model_file" --repo-type model -d /workspace/models 2>>$LOGFILE
  else
    echo "No HF_TOKEN set, using wget for direct download" | tee -a $LOGFILE
    wget -c -O "/workspace/models/$model_file" "https://huggingface.co/$hf_repo/resolve/main/$model_file" 2>>$LOGFILE
  fi
}

# Auto-download fallback if enabled and nothing was selected
if [ -z "$MODEL_NAME" ] && [ "$AUTO_DOWNLOAD" == "true" ]; then
  if [ ! -f "/workspace/models/$FALLBACK_MODEL" ]; then
    echo "Downloading fallback model..." | tee -a $LOGFILE
    download_model "$FALLBACK_MODEL" "$FALLBACK_HF_REPO"
  else
    echo "Fallback model already exists locally." | tee -a $LOGFILE
  fi
  MODEL_NAME="$FALLBACK_MODEL"
fi

# Final check before launch
if [ -n "$MODEL_NAME" ]; then
  CMD_ARGS+=" --model $MODEL_NAME"
  CMD_ARGS+=" --model-dir /workspace/models"  # Critical for GGUF

  # GGUF loader (llama.cpp)
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS+=" --loader llama.cpp"
  fi
else
  echo "No model to load, exiting." | tee -a $LOGFILE
  exit 1
fi

# MoE (Mixture of Experts) config
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS+=" --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

echo "Final launch command args: $CMD_ARGS" | tee -a $LOGFILE
echo "---------------------------------" | tee -a $LOGFILE

# Launch server
exec ./start_linux.sh $CMD_ARGS 2>&1 | tee -a $LOGFILE
