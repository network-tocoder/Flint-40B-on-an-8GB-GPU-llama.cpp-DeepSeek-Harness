#!/bin/bash
# The exact server settings used in the video (RTX 3060 Ti, 8 GB).
./build/bin/llama-server \
  -m models/flint-UD-Q4_K_XL.gguf \
  -ngl 99 \
  -fa 1 \
  --n-cpu-moe 40 \
  -c 32768 \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 20 \
  --host 127.0.0.1 --port 8081
