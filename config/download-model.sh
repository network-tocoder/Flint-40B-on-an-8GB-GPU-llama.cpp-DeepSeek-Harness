#!/bin/bash
# Download the Unsloth GGUF of Flint (single file, ~23.3 GB).
pip install -U huggingface_hub
hf download unsloth/flint-GGUF flint-UD-Q4_K_XL.gguf --local-dir ./models
