# Load this in EVERY new terminal before running dsh:   source config/dsh-env.sh
# If dsh can't find your settings it silently uses DeepSeek's cloud
# and the first thing you see is a MISSING_CREDENTIAL error.
export DSH_HOME="$HOME/dshhome"            # folder that holds settings.yaml
export LLAMACPP_API_KEY="local"            # any value - llama.cpp doesn't check it
export DSH_PERMISSION_MODE="danger-full-access"   # lets the agent run commands without asking (test box only)
