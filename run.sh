#!/bin/bash
# TGW RUN.SH v28.2 - GGUF Auto-detect Fix + ExLlama2 Re-enabled + HF token support

LOGFILE="/app/run.log"
echo "----- Starting run.sh at $(date) -----" | tee $LOGFILE

CMD_ARGS="--listen --extensions deep_reason,api"

# Add multimodal extension if enabled
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
  echo "Multimodal extension enabled." | tee -a $LOGFILE
  CMD_ARGS="${CMD_ARGS},multimodal"
fi

# Function: Find .gguf models in /workspace/models (non-recursive)
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

# MODEL_NAME env var takes priority
if [ -z "$MODEL_NAME" ]; then
  MODEL_PATH=$(find_gguf_model)
  if [ $? -eq 0 ]; then
    MODEL_NAME=$(basename "$MODEL_PATH")
    echo "Auto-detected model: $MODEL_NAME" | tee -a $LOGFILE
  else
    echo "No model specified and no local model found." | tee -a $LOGFILE
    MODEL_NAME=""
  fi
else
  echo "Using MODEL_NAME from env: $MODEL_NAME" | tee -a $LOGFILE
fi

# Default fallback model
DEFAULT_MODEL="mlabonne_gemma-3-27b-it-abliterated-Q5_K_L.gguf"
DEFAULT_HF_REPO="bartowski/mlabonne_gemma-3-27b-it-abliterated-GGUF"

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

if [ -z "$MODEL_NAME" ] && [ "$AUTO_DOWNLOAD" == "true" ]; then
  if [ ! -f "/workspace/models/$DEFAULT_MODEL" ]; then
    echo "Default model not found locally, starting download..." | tee -a $LOGFILE
    download_model "$DEFAULT_MODEL" "$DEFAULT_HF_REPO"
    MODEL_NAME="$DEFAULT_MODEL"
  else
    echo "Default model found locally." | tee -a $LOGFILE
    MODEL_NAME="$DEFAULT_MODEL"
  fi
fi

# Add model to command args
if [ -n "$MODEL_NAME" ]; then
  CMD_ARGS+=" --model $MODEL_NAME"

  # Set loader only if GGUF file is used
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS+=" --loader llama.cpp"
  fi
else
  echo "No model to load, exiting." | tee -a $LOGFILE
  exit 1
fi

# Mixture of Experts (MoE)
if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS+=" --num_experts_per_token $NUM_EXPERTS_PER_TOKEN"
fi

echo "Final launch command args: $CMD_ARGS" | tee -a $LOGFILE
echo "---------------------------------" | tee -a $LOGFILE

# Start server
exec ./start_linux.sh $CMD_ARGS 2>&1 | tee -a $LOGFILE
