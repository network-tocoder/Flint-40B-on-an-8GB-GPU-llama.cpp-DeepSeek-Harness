#!/bin/bash
# Speed test: how many expert layers to keep on the CPU.
# 49 = all experts on CPU, 40 = 9 expert layers back on the GPU.
# Stop llama-server first - the benchmark needs the whole GPU to itself.
./build/bin/llama-bench \
  -m models/flint-UD-Q4_K_XL.gguf \
  -ngl 99 -fa 1 \
  --n-cpu-moe 49,40
