# DeepSeek Harness (dsh) setup

Version used in the video: `@deepseek-ai/dsh` **0.1.5-rc.2** (developer preview, MIT).

## 1. Install
```bash
npm install -g @deepseek-ai/dsh
```

## 2. Approve the skipped install scripts
Newer npm versions silently skip some install scripts. The one it skips is what lets the
agent run shell commands, so without this the agent can't run your tests.
```bash
npm install-scripts approve node-pty @deepseek-ai/dsh-subprocess-local koffi
```

## 3. Point it at your local server
```bash
mkdir -p ~/dshhome
cp config/dsh-settings.yaml ~/dshhome/settings.yaml
source config/dsh-env.sh
```

## 4. Run a job (headless profile)
```bash
cd testrepo
dsh --profile headless "$(cat ../prompts/02-agent-bugfix.txt)"
```
`--profile headless` runs one fresh session, prints the final answer and exits.

## Common problems
| Symptom | Cause | Fix |
|---|---|---|
| `MISSING_CREDENTIAL` | settings not loaded, dsh fell back to the cloud | `source config/dsh-env.sh` in that terminal |
| Agent can't run commands | npm skipped install scripts | step 2 |
| Write tool rejects calls (`justification`, `sandbox_permissions`) | model adds extra arguments | add [`prompts/rule.txt`](../prompts/rule.txt) to the prompt |
