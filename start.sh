#!/bin/bash
python3 server.py \
  --listen \
  --model-dir /workspace/models \
  --loader exllama2 \
  --extensions text-generation-webui-deep_reason
