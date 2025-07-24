#!/bin/bash
# TGW-RUN-v29-AUTODETECT-FULLPATH

LOGFILE="/app/run.log"
echo "----- Starting run.sh at $(date) -----" | tee $LOGFILE

CMD_ARGS="--listen --extensions deep_reason,api"

# Optional multimodal extension
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
  echo "Multimodal extension enabled." | tee -a $LOGFILE
  CMD_ARGS="${CMD_ARGS},multimodal"
fi

# Find .gguf model in /workspace/models
find_gguf_model() {
  echo "Looking for .gguf models in /workspace/models ..." | tee -a $LOGFILE
  local files=()
  while IFS= read -r -d $'\0' file; do
    files+=("$file")
  done < <(find /workspace/models -maxdepth 1 -type f -name '*.gguf' -print0)

  if [ ${#files[@]} -eq 0 ]; then
    echo "No .gguf model files found." | tee -a $LOGFILE
    return 1
  elif [ ${#files[@]} -eq 1 ]; then
    echo "Found one model: ${files[0]}" | tee -a $LOGFILE
    echo "${files[0]}"
    return 0
  else
    echo "Multiple models found, picking the newest by time:" | tee -a $LOGFILE
    local latest=$(ls -1t "${files[@]}" | head -n1)
    echo "$latest" | tee -a $LOGFILE
    echo "$latest"
    return 0
  fi
}

# Auto-detect model if not specified
if [ -z "$MODEL_NAME" ]; then
  MODEL_PATH=$(find_gguf_model)
  if [ $? -eq 0 ]; then
    MODEL_NAME=$(basename "$MODEL_PATH")
    MODEL_PATH="$MODEL_PATH"
    echo "Auto-detected model: $MODEL_NAME" | tee -a $LOGFILE
  else
    echo "No model specified and no local model found." | tee -a $LOGFILE
    MODEL_NAME=""
  fi
else
  echo "Using MODEL_NAME from env: $MODEL_NAME" | tee -a $LOGFILE
  MODEL_PATH="/workspace/models/$MODEL_NAME"
fi

# Download fallback model if enabled
DEFAULT_MODEL="mlabonne_gemma-3-27b-it-abliterated-Q5_K_L.gguf"
DEFAULT_HF_REPO="bartowski/mlabonne_gemma-3-27b-it-abliterated-GGUF"

download_model() {
  local model_file="$1"
  local hf_repo="$2"
  echo "Attempting to download $model_file from $hf_repo ..." | tee -a $LOGFILE
  if [ -n "$HF_TOKEN" ]; then
    huggingface-cli login --token "$HF_TOKEN" 2>>$LOGFILE
    huggingface-cli repo download "$hf_repo" --filename "$model_file" --repo-type model -d /workspace/models 2>>$LOGFILE
  else
    wget -c -O "/workspace/models/$model_file" "https://huggingface.co/$hf_repo/resolve/main/$model_file" 2>>$LOGFILE
  fi
}

if [ -z "$MODEL_NAME" ] && [ "$AUTO_DOWNLOAD" == "true" ]; then
  if [ ! -f "/workspace/models/$DEFAULT_MODEL" ]; then
    echo "Downloading default model..." | tee -a $LOGFILE
    download_model "$DEFAULT_MODEL" "$DEFAULT_HF_REPO"
    MODEL_NAME="$DEFAULT_MODEL"
    MODEL_PATH="/workspace/models/$DEFAULT_MODEL"
  else
    MODEL_NAME="$DEFAULT_MODEL"
    MODEL_PATH="/workspace/models/$DEFAULT_MODEL"
    echo "Default model already present." | tee -a $LOGFILE
  fi
fi

if [ -n "$MODEL_NAME" ]; then
  CMD_ARGS+=" --model $MODEL_PATH"
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS+=" --loader llama.cpp"
  fi
else
  echo "No model specified or found. Exiting." | tee -a $LOGFILE
  exit 1
fi

# Add MoE param if set
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS+=" --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

echo "Final launch command args: $CMD_ARGS" | tee -a $LOGFILE
echo "---------------------------------" | tee -a $LOGFILE

exec ./start_linux.sh $CMD_ARGS 2>&1 | tee -a $LOGFILE
