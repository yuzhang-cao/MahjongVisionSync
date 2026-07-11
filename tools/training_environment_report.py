#!/usr/bin/env python3
"""Write a reproducible, non-sensitive report for the Windows training node."""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


PACKAGES = (
    "torch",
    "torchvision",
    "torchaudio",
    "ultralytics",
    "onnx",
    "onnxruntime",
    "numpy",
    "Pillow",
    "opencv-python",
)


def package_versions() -> dict[str, str | None]:
    versions: dict[str, str | None] = {}
    for package in PACKAGES:
        try:
            versions[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            versions[package] = None
    return versions


def torch_gpu_state() -> dict[str, object]:
    try:
        import torch
    except ImportError:
        return {"available": False, "error": "torch is not installed"}

    available = bool(torch.cuda.is_available())
    state: dict[str, object] = {
        "available": available,
        "torch_cuda_version": torch.version.cuda,
        "device_count": torch.cuda.device_count() if available else 0,
    }
    if available:
        state["devices"] = [torch.cuda.get_device_name(index) for index in range(torch.cuda.device_count())]
    return state


def nvidia_smi_state() -> dict[str, object]:
    command = [
        "nvidia-smi",
        "--query-gpu=name,driver_version,memory.total",
        "--format=csv,noheader,nounits",
    ]
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"available": False, "error": str(error)}
    return {
        "available": result.returncode == 0,
        "returncode": result.returncode,
        "output": [line.strip() for line in result.stdout.splitlines() if line.strip()],
        "error": result.stderr.strip() or None,
    }


def build_report() -> dict[str, object]:
    return {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "python_executable": sys.executable,
        "packages": package_versions(),
        "torch_gpu": torch_gpu_state(),
        "nvidia_smi": nvidia_smi_state(),
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    parser.add_argument("--require-gpu", action="store_true", help="Fail when PyTorch CUDA is unavailable")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = build_report()
    rendered = json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    if args.require_gpu and not report["torch_gpu"]["available"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
