#!/bin/bash
# TGW RUN.SH v33 - Corrects extension argument formatting.

LOGFILE="/app/run.log"
echo "----- Starting run.sh at $(date) -----" | tee $LOGFILE

# --- Extension Handling ---
# Extensions must be a single, comma-separated string.
# This section corrects the bug from the previous version.
BASE_EXTENSIONS="deep_reason,api"
if [ "$ENABLE_MULTIMODAL" == "true" ]; then
  echo "Multimodal extension enabled via environment variable." | tee -a $LOGFILE
  FINAL_EXTENSIONS="$BASE_EXTENSIONS,multimodal"
else
  FINAL_EXTENSIONS="$BASE_EXTENSIONS"
fi

# --- Argument Array ---
# The array will now be built with the correctly formatted extension list.
CMD_ARGS_ARRAY=()
CMD_ARGS_ARRAY+=(--extensions "$FINAL_EXTENSIONS")

# --- Model Selection Logic (No changes) ---
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

if [ -n "$MODEL_NAME" ]; then
  echo "Using model: $MODEL_NAME" | tee -a $LOGFILE
  CMD_ARGS_ARRAY+=(--model "$MODEL_NAME")
  CMD_ARGS_ARRAY+=(--model-dir /workspace/models)
  if [[ "$MODEL_NAME" == *.gguf ]]; then
    CMD_ARGS_ARRAY+=(--loader llama.cpp)
  fi
else
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
    exit 1
  fi
fi

if [ -n "$NUM_EXPERTS_PER_TOKEN" ]; then
  CMD_ARGS_ARRAY+=(--num_experts_per_token "$NUM_EXPERTS_PER_TOKEN")
fi

echo "Additional args: ${CMD_ARGS_ARRAY[@]}" | tee -a $LOGFILE
echo "---------------------------------" | tee -a $LOGFILE

# --- Launch Server ---
cd /app
./start_linux.sh "${CMD_ARGS_ARRAY[@]}" 2>&1 | tee -a $LOGFILE
