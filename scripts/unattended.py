#!/usr/bin/env python3
"""Unattended Flint tests against a running llama-server.
Usage: python unattended.py [--port 8081] [--repo ~/testrepo] [--out results]
Writes results.md (summary table) and log.jsonl (every raw result) to --out.
"""
import argparse, json, os, re, shutil, subprocess, sys, time, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8081)
ap.add_argument("--repo", default=os.path.expanduser("~/testrepo"))
ap.add_argument("--out", default="results")
ap.add_argument("--runs", type=int, default=3)
args = ap.parse_args()
URL = f"http://127.0.0.1:{args.port}/v1/chat/completions"
os.makedirs(args.out, exist_ok=True)
LOG = open(os.path.join(args.out, "log.jsonl"), "a")
rows = []


def say(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def chat(content, max_tokens=4096, timeout=1800):
    body = json.dumps({"messages": [{"role": "user", "content": content}],
                       "max_tokens": max_tokens, "temperature": 1.0, "top_p": 0.95, "top_k": 20,
                       "cache_prompt": False}).encode()
    req = urllib.request.Request(URL, body, {"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        resp = json.load(r)
    wall = time.time() - t0
    t = resp.get("timings", {})
    msg = resp["choices"][0]["message"]
    return {"text": msg.get("content") or "", "reasoning": msg.get("reasoning_content") or "",
            "wall_s": round(wall, 1), "prompt_n": t.get("prompt_n"),
            "prompt_tps": round(t.get("prompt_per_second", 0), 1),
            "gen_n": t.get("predicted_n"), "gen_tps": round(t.get("predicted_per_second", 0), 1),
            "finish": resp["choices"][0].get("finish_reason")}


def record(test, r, **extra):
    row = {"test": test, **{k: v for k, v in r.items() if k not in ("text", "reasoning")}, **extra}
    rows.append(row)
    LOG.write(json.dumps({**row, "text": r.get("text", "")[:4000]}) + "\n"); LOG.flush()
    say(f"{test}: gen {row.get('gen_tps')} tok/s, prompt {row.get('prompt_tps')} tok/s, "
        f"{row.get('gen_n')} tokens, {row.get('wall_s')}s {extra if extra else ''}")


# ---- Test A: short-prompt chat speed ----
say("TEST A: chat speed (short prompt)")
for i in range(args.runs):
    try:
        record(f"A-chat-{i+1}", chat("Write a Python function to merge two sorted lists, with tests."))
    except Exception as e:
        say(f"A run {i+1} failed: {e}")

# ---- Test B: long context speed + recall (needle in the middle) ----
say("TEST B: long-context speed and recall")
filler = ("The warehouse log records routine stock movements for ordinary items. " * 8 + "\n")
for target_k in (4, 12, 24):
    n_lines = int(target_k * 1000 / 130)  # ~130 tokens per filler line (approx)
    lines = [filler] * n_lines
    lines.insert(n_lines // 2, "IMPORTANT: the secret vault code is 7413.\n")
    prompt = "".join(lines) + "\nWhat is the secret vault code mentioned in the log above? Answer with only the number."
    try:
        r = chat(prompt, max_tokens=2048)
        found = "7413" in r["text"]
        record(f"B-context-{target_k}K", r, recall="PASS" if found else "FAIL")
    except Exception as e:
        say(f"B {target_k}K failed: {e}")

# ---- Test C: one-shot bug fix (no agent), verified by pytest ----
say("TEST C: one-shot bug fix verified by pytest")
src = {p: open(os.path.join(args.repo, p)).read() for p in ("shop/pricing.py", "shop/ranking.py", "tests/test_shop.py")}
prompt = ("These tests fail. Fix the bugs in shop/pricing.py and shop/ranking.py so all tests pass. "
          "Do not change the tests. Reply with the FULL corrected content of each file you change, each as:\n"
          "### FILE: <path>\n```python\n<code>\n```\n\n" +
          "\n".join(f"### FILE: {p}\n```python\n{c}```\n" for p, c in src.items()))
for i in range(args.runs):
    work = f"/tmp/fixrun{i+1}"
    shutil.rmtree(work, ignore_errors=True); shutil.copytree(args.repo, work, ignore=shutil.ignore_patterns(".git"))
    try:
        r = chat(prompt, max_tokens=16384)
        blocks = re.findall(r"### FILE:\s*(\S+)\s*\n```(?:python)?\n(.*?)```", r["text"], re.S)
        for path, code in blocks:
            if path.startswith("shop/") and ".." not in path:
                open(os.path.join(work, path), "w").write(code)
        res = subprocess.run([sys.executable, "-m", "pytest", "-q"], cwd=work, capture_output=True, text=True, timeout=120)
        last = (res.stdout.strip().splitlines() or ["?"])[-1]
        record(f"C-fix-{i+1}", r, files_changed=len(blocks), pytest=last,
               result="PASS" if res.returncode == 0 else "FAIL")
    except Exception as e:
        say(f"C run {i+1} failed: {e}")

# ---- Summary ----
md = ["| Test | Gen tok/s | Prompt tok/s | Prompt tokens | Gen tokens | Wall s | Result |",
      "|---|---|---|---|---|---|---|"]
for r in rows:
    res = r.get("recall") or (f"{r.get('result')} ({r.get('pytest')})" if "result" in r else r.get("finish", ""))
    md.append(f"| {r['test']} | {r.get('gen_tps')} | {r.get('prompt_tps')} | {r.get('prompt_n')} | {r.get('gen_n')} | {r.get('wall_s')} | {res} |")
open(os.path.join(args.out, "results.md"), "w").write("\n".join(md) + "\n")
say("DONE. Summary:\n" + "\n".join(md))
