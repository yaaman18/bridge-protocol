#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def _parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    return parser.parse_args()


def _load_upstream(repo: Path):
    model_path = repo / "models" / "recursive_reasoning" / "trm.py"
    if not model_path.is_file():
        raise FileNotFoundError(f"upstream TRM model not found: {model_path}")
    sys.path.insert(0, str(repo))

    import torch

    # PyTorch 2.2 is the last macOS x86_64 wheel. Upstream only needs Buffer's
    # tensor behavior for CPU inference; persistent buffers are restored below.
    if not hasattr(torch.nn, "Buffer"):
        torch.nn.Buffer = lambda tensor, persistent=True: tensor

    from models.recursive_reasoning.trm import TinyRecursiveReasoningModel_ACTV1

    return torch, TinyRecursiveReasoningModel_ACTV1


def _git_commit(repo: Path):
    result = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _default_config(tokens, steps):
    batch_size = len(tokens)
    seq_len = len(tokens[0])
    vocab_size = max(max(row) for row in tokens) + 2
    return {
        "batch_size": batch_size,
        "seq_len": seq_len,
        "puzzle_emb_ndim": 0,
        "num_puzzle_identifiers": 1,
        "vocab_size": max(vocab_size, 4),
        "H_cycles": 2,
        "L_cycles": 2,
        "H_layers": 0,
        "L_layers": 2,
        "hidden_size": 16,
        "expansion": 2.0,
        "num_heads": 2,
        "pos_encodings": "rope",
        "rms_norm_eps": 1e-5,
        "rope_theta": 10000.0,
        "halt_max_steps": steps,
        "halt_exploration_prob": 0.0,
        "forward_dtype": "float32",
        "mlp_t": False,
        "puzzle_emb_len": 0,
        "no_ACT_continue": True,
    }


def _validate_tokens(tokens):
    if not isinstance(tokens, list) or not tokens or not isinstance(tokens[0], list):
        raise ValueError("tokens must be a nonempty matrix")
    width = len(tokens[0])
    if width == 0 or any(len(row) != width for row in tokens):
        raise ValueError("token rows must be nonempty and have equal length")
    if any(not isinstance(value, int) or value < 0 for row in tokens for value in row):
        raise ValueError("tokens must contain nonnegative integers")


def _load_checkpoint(torch, model, checkpoint):
    path = Path(checkpoint).expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(f"checkpoint not found: {path}")
    state = torch.load(str(path), map_location="cpu", weights_only=True)
    if not isinstance(state, dict):
        raise ValueError("checkpoint must contain a state dictionary")

    normalized = {}
    for key, value in state.items():
        while key.startswith("_orig_mod.") or key.startswith("module."):
            key = key.split(".", 1)[1]
        if key.startswith("model."):
            key = key[len("model.") :]
        normalized[key] = value

    for key, attribute in (("inner.H_init", "H_init"), ("inner.L_init", "L_init")):
        if key in normalized:
            getattr(model.inner, attribute).copy_(normalized.pop(key))

    missing, unexpected = model.load_state_dict(normalized, strict=False)
    if missing or unexpected:
        raise ValueError(
            f"checkpoint/config mismatch; missing={list(missing)}, unexpected={list(unexpected)}"
        )
    return str(path)


def _infer(torch, model_cls, request):
    tokens = request.get("tokens", [[0, 1, 2, 1]])
    _validate_tokens(tokens)
    steps = int(request.get("steps", 3))
    if steps < 1:
        raise ValueError("steps must be positive")

    config = _default_config(tokens, steps)
    config.update(request.get("config") or {})
    config["batch_size"] = len(tokens)
    config["seq_len"] = len(tokens[0])
    config["halt_max_steps"] = steps
    if config["forward_dtype"] != "float32":
        raise ValueError("the CPU bridge requires forward_dtype=float32")

    torch.manual_seed(int(request.get("seed", 0)))
    torch.set_num_threads(1)
    model = model_cls(config).to("cpu").eval()
    checkpoint = request.get("checkpoint")
    loaded_checkpoint = None
    if checkpoint is not None:
        loaded_checkpoint = _load_checkpoint(torch, model, checkpoint)

    batch = {
        "inputs": torch.tensor(tokens, dtype=torch.int64),
        "puzzle_identifiers": torch.tensor(
            request.get("puzzle_identifiers", [0] * len(tokens)), dtype=torch.int64
        ),
    }
    carry = model.initial_carry(batch)
    outputs = None
    with torch.no_grad():
        for _ in range(steps):
            carry, outputs = model(carry, batch)
    assert outputs is not None
    logits = outputs["logits"].to(torch.float32)
    return {
        "ok": True,
        "command": "infer",
        "predictions": torch.argmax(logits, dim=-1).tolist(),
        "logits": logits.tolist(),
        "q_halt_logits": outputs["q_halt_logits"].to(torch.float32).tolist(),
        "steps": carry.steps.tolist(),
        "checkpoint": loaded_checkpoint,
        "config": config,
    }


def main():
    args = _parse_args()
    repo = Path(args.repo).expanduser().resolve()
    try:
        request = json.load(sys.stdin)
        command = request.get("command")
        torch, model_cls = _load_upstream(repo)
        if command == "health":
            response = {
                "ok": True,
                "command": "health",
                "python_version": sys.version.split()[0],
                "torch_version": torch.__version__,
                "cuda_available": torch.cuda.is_available(),
                "upstream_repo": str(repo),
                "upstream_commit": _git_commit(repo),
            }
        elif command in ("smoke", "infer"):
            response = _infer(torch, model_cls, request)
            response["command"] = command
        else:
            raise ValueError(f"unsupported command: {command}")
    except Exception as error:
        response = {"ok": False, "error": f"{type(error).__name__}: {error}"}
    json.dump(response, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
