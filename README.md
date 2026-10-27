# Flint 40B on an 8GB GPU: llama.cpp + DeepSeek Harness (local coding agent)

![GPU](https://img.shields.io/badge/Tested%20on-RTX%203060%20Ti%208GB-76b900?style=for-the-badge&logo=nvidia&logoColor=white)
![Model](https://img.shields.io/badge/Model-Flint%2040B%20(2.5B%20active)-06b6d4?style=for-the-badge)
![Quant](https://img.shields.io/badge/Quant-UD--Q4__K__XL%2023.3GB-0ea5e9?style=for-the-badge)
![Agent](https://img.shields.io/badge/Agent-DeepSeek%20Harness-8b5cf6?style=for-the-badge)
![Engine](https://img.shields.io/badge/Engine-llama.cpp-000000?style=for-the-badge)
![Cloud](https://img.shields.io/badge/Cloud-Not%20Required-red?style=for-the-badge)
![API](https://img.shields.io/badge/API-OpenAI%20Compatible-black?style=for-the-badge)

Run **Flint**, Recursive's 40B mixture-of-experts coding model, on a single **8 GB graphics card**, and drive it with **DeepSeek Harness** as a fully local coding agent. This repo has the exact **configs**, **prompts**, the **test project** with its hidden grader, and the **raw agent logs** from the video. Nothing leaves your machine.

[![Subscribe](https://img.shields.io/badge/Subscribe-NetworkCoder-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@NetworkCoder?sub_confirmation=1)

⭐ If this helped, **star the repo** so more people can find it.

## Results

| Level | Test | Result |
|:---:|---|---|
| 1 | Speed (`--n-cpu-moe 40`) | **~37 tok/s** writing · **~350 tok/s** reading |
| 2 | Long memory (needle in 2.7K / 8.2K / 16.4K-token prompts) | **3 / 3** |
| 3 | Single-prompt bug fix, no tools | **3 / 3** |
| 4 | Agent bug fix (DeepSeek Harness) | **2 / 3** alone → **2 / 2** with [one rule](prompts/rule.txt), ~2× faster |
| 5 | New feature from a spec, graded by 18 hidden tests | **18 / 18**, twice |

> Small sample, one machine. Treat these as a real-world check, not a benchmark.

## Hardware

| Spec | |
|---|---|
| GPU | RTX 3060 Ti · 8 GB |
| CPU | AMD EPYC 7302 · 16 cores |
| System RAM | 64 GB (used in the test) |
| Model | Flint · Unsloth `UD-Q4_K_XL` GGUF (~23.3 GB, one file) |
| Split | ≈ 5 GB on the GPU · ≈ 18 GB of experts in system RAM |
| Context | 32K |

### How much RAM do you need?

| System RAM | |
|---|---|
| 16 GB | ✗ won't fit |
| 24 GB | bare minimum on a clean system |
| 32 GB | ✓ comfortable minimum |
| 64 GB | what I tested with |

About 18 GB of the model sits in system RAM. If RAM runs short, the OS drops expert pages and re-reads them from the SSD, and speed falls hard. The experts run from RAM, so **memory speed matters**. My numbers are on 8-channel server memory, so a typical 2-channel desktop will be a little lower.

## The stack

1. **GPU (8 GB)** — attention, shared layers and the context cache.
2. **System RAM** — the expert layers. Only 6 of 256 experts (+1 shared) fire per token, so the CPU only touches a small slice each time.
3. **llama.cpp** — splits the model with `--n-cpu-moe` and serves an OpenAI-compatible API.
4. **DeepSeek Harness** — the agent: reads files, edits code, runs tests.

## Setup

**Before you start**

| Need | Why |
|---|---|
| NVIDIA GPU, 8 GB+ | runs the shared layers |
| 32 GB system RAM (24 GB bare minimum) | holds the experts |
| CUDA toolkit, CMake, Git | to build llama.cpp |
| Node.js + npm | for DeepSeek Harness |
| Python 3 + pytest | for the test project |

**1. Build llama.cpp with CUDA** ([`config/build-llama.cpp.sh`](config/build-llama.cpp.sh))
```bash
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j
```

**2. Download the model** ([`config/download-model.sh`](config/download-model.sh))
```bash
hf download unsloth/flint-GGUF flint-UD-Q4_K_XL.gguf --local-dir ./models
```

**3. (Optional) Benchmark** ([`config/llama-bench.sh`](config/llama-bench.sh))
```bash
./build/bin/llama-bench -m models/flint-UD-Q4_K_XL.gguf -ngl 99 -fa 1 --n-cpu-moe 49,40
```
| `--n-cpu-moe` | Writing speed |
|:---:|---|
| 49 (all experts on CPU) | ~34 tok/s |
| 40 (9 expert layers back on GPU) | ~37.5 tok/s |

> Stop `llama-server` before benchmarking. Two processes sharing an 8 GB card will run out of memory.

**4. Start the model server** ([`config/llama-server.sh`](config/llama-server.sh))
```bash
./build/bin/llama-server \
  -m models/flint-UD-Q4_K_XL.gguf \
  -ngl 99 -fa 1 \
  --n-cpu-moe 40 \
  -c 32768 \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 20 \
  --host 127.0.0.1 --port 8081
```
| Flag | What it does |
|---|---|
| `-ngl 99` | put every layer it can on the GPU |
| `--n-cpu-moe 40` | keep the experts of 40 layers in system RAM (the 8 GB sweet spot) |
| `-fa 1` | flash attention on |
| `-c 32768` | 32K context |
| `--jinja` | use the model's own chat template (needed for tool calls) |
| `--temp 1.0 --top-p 0.95 --top-k 20` | Recursive's recommended sampling |

Loads in a few seconds. Open `http://127.0.0.1:8081` for the built-in web chat.

**5. Install DeepSeek Harness and point it at the server** ([`config/dsh-setup.md`](config/dsh-setup.md))
```bash
npm install -g @deepseek-ai/dsh
npm install-scripts approve node-pty @deepseek-ai/dsh-subprocess-local koffi   # don't skip this
mkdir -p ~/dshhome && cp config/dsh-settings.yaml ~/dshhome/settings.yaml
source config/dsh-env.sh
```
The provider block from [`config/dsh-settings.yaml`](config/dsh-settings.yaml):
```yaml
llm-pi-ai:
  providers:
    llamacpp:
      api: openai-completions
      baseURL: http://127.0.0.1:8081/v1
      models:
        - id: flint
          contextWindow: 32768
```

**6. Create the test projects** ([`test-project/`](test-project))
```bash
bash test-project/make_testrepo.sh ~/testrepo                 # 3 planted bugs (levels 3 & 4)
bash test-project/make_task2.sh   ~/testrepo2 ~/.grader       # new feature + hidden grader (level 5)
```

**7. Run the agent**
```bash
cd ~/testrepo
dsh --profile headless "$(cat /path/to/prompts/02b-agent-bugfix-with-rule.txt)"
python -m pytest -q
```

## The prompts

**Level 3 — single-prompt fix, no tools** ([`prompts/01-single-prompt-fix.txt`](prompts/01-single-prompt-fix.txt)) — run by [`scripts/unattended.py`](scripts/unattended.py), which also runs levels 1 and 2:
```bash
python scripts/unattended.py --port 8081 --repo ~/testrepo --out results
```

**Level 4 — agent bug fix** ([`prompts/02-agent-bugfix.txt`](prompts/02-agent-bugfix.txt))
```text
Run the tests with python -m pytest -q. Some of them fail because of bugs in the shop package.
Find and fix the bugs so that every test passes. Do not change the tests.
```

**The one-line fix** ([`prompts/rule.txt`](prompts/rule.txt)) — add it to any agent prompt:
```text
RULE: When you call the write or edit tool, pass ONLY the file path and the content.
Never add justification or sandbox_permissions. Never describe a change without making it.
```

**Level 5 — new feature from a spec** ([`prompts/03-new-feature-cart.txt`](prompts/03-new-feature-cart.txt))
```text
Read SPEC.md and implement shop/cart.py exactly as described. Write your own tests in
tests/test_cart.py and make sure python -m pytest -q passes.
```
Then grade it with the hidden tests the agent never saw:
```bash
cd ~/testrepo2 && python -m pytest -q ~/.grader/test_hidden.py
```

## Tips

- **`--n-cpu-moe 40` on 8 GB.** Lower values put more experts on the GPU but run out of memory on an 8 GB card.
- **One process on the GPU.** Don't run `llama-bench` while `llama-server` is up.
- **Load your settings every time.** If dsh can't find them, it quietly falls back to DeepSeek's cloud.
- **Approve npm install scripts.** Otherwise the agent installs fine but can't run commands.
- **Add the rule.** Flint sometimes adds extra arguments to the write tool or describes a fix without making it. One line in the prompt stopped both in my runs.
- **Grade with hidden tests.** An agent passing its own tests isn't proof. Keep a grader outside the project.

## Which GPUs?

NVIDIA RTX 30-series or newer with **8 GB or more**. With more VRAM, lower `--n-cpu-moe` to move more experts onto the GPU and go faster. System RAM matters as much as the GPU here — see the RAM table above.

## Related

| Video | Repo |
|---|---|
| Run a 125B model on one GPU (Strata + Qwen 3.8 Flash-Next) | [link](https://github.com/network-tocoder/Run-a-125B-AI-Model-on-One-GPU-Strata-Qwen3.8-Flash-Next) |
| Free local AI coding agent — 125B on 16GB (Strata + opencode) | [link](https://github.com/network-tocoder/free-local-ai-coding-agent-125b-on-16gb-gpu-strata-opencode) |
| 125B local AI on a 12GB GPU (Strata + Pi 1.0) | [link](https://github.com/network-tocoder/125B-Local-AI-on-a-12GB-GPU-Strata-Pi-1.0-Coding-Agent) |

## Files

| File | What's in it |
|---|---|
| [`config/build-llama.cpp.sh`](config/build-llama.cpp.sh) | Build llama.cpp with CUDA |
| [`config/download-model.sh`](config/download-model.sh) | Download the Unsloth GGUF |
| [`config/llama-bench.sh`](config/llama-bench.sh) | Speed test at `--n-cpu-moe` 49 and 40 |
| [`config/llama-server.sh`](config/llama-server.sh) | The exact server flags used in the video |
| [`config/dsh-settings.yaml`](config/dsh-settings.yaml) | DeepSeek Harness → local llama.cpp, no API key |
| [`config/dsh-env.sh`](config/dsh-env.sh) | Environment to load in every terminal |
| [`config/dsh-setup.md`](config/dsh-setup.md) | Install steps and the three common problems |
| [`prompts/01-single-prompt-fix.txt`](prompts/01-single-prompt-fix.txt) | Level 3 — fix the bugs in one reply, no tools |
| [`prompts/02-agent-bugfix.txt`](prompts/02-agent-bugfix.txt) | Level 4 — agent bug fix |
| [`prompts/02b-agent-bugfix-with-rule.txt`](prompts/02b-agent-bugfix-with-rule.txt) | Level 4 — same, with the one-line rule |
| [`prompts/03-new-feature-cart.txt`](prompts/03-new-feature-cart.txt) | Level 5 — build a cart from SPEC.md |
| [`prompts/rule.txt`](prompts/rule.txt) | The one line that fixed the agent |
| [`test-project/make_testrepo.sh`](test-project/make_testrepo.sh) | Test project with 3 planted bugs |
| [`test-project/make_task2.sh`](test-project/make_task2.sh) | Feature task + 18 hidden tests (kept outside the project) |
| [`scripts/unattended.py`](scripts/unattended.py) | Levels 1–3 against a running server, writes `results.md` |
| [`logs/`](logs) | Raw DeepSeek Harness output from the agent runs |

## Credits

Flint by [Recursive](https://huggingface.co/RecursiveSI/flint) (Apache 2.0) · GGUF by [Unsloth](https://huggingface.co/unsloth/flint-GGUF) · [llama.cpp](https://github.com/ggml-org/llama.cpp) · [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (MIT)
