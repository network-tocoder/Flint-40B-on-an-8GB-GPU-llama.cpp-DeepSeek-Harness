#!/bin/bash
# Build llama.cpp from source with CUDA (NVIDIA GPU).
set -e
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j
# binaries end up in build/bin/ (llama-server, llama-bench, ...)
