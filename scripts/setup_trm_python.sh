#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$ROOT/external/TinyRecursiveModels"
VENV="$ROOT/.venv-trm"

if [[ ! -d "$UPSTREAM/.git" ]]; then
  mkdir -p "$ROOT/external"
  git clone git@github.com:SamsungSAILMontreal/TinyRecursiveModels.git "$UPSTREAM"
fi

command -v uv >/dev/null 2>&1 || {
  echo "uv is required: https://docs.astral.sh/uv/" >&2
  exit 1
}

uv venv --allow-existing --python python3 "$VENV"
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "x86_64" ]]; then
  uv pip install --python "$VENV/bin/python" \
    -r "$ROOT/python/trm_bridge/requirements-macos-cpu.txt"
else
  echo "The bridge venv was created, but upstream training dependencies are platform-specific." >&2
  echo "Install PyTorch for the target CUDA/CPU platform, then external/TinyRecursiveModels/requirements.txt." >&2
fi

"$VENV/bin/python" "$ROOT/python/trm_bridge/bridge.py" \
  --repo "$UPSTREAM" <<<'{"command":"health"}'
