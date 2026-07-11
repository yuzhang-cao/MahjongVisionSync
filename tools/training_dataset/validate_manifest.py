"""Command line entry point for MahjongVisionSync dataset manifest validation."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .validator import validate_manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate a MahjongVisionSync training dataset manifest.")
    parser.add_argument("manifest", type=Path, help="Path to the manifest JSON file")
    args = parser.parse_args(argv)

    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    except OSError as error:
        print(f"failed to read manifest: {error}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as error:
        print(f"invalid JSON: {error}", file=sys.stderr)
        return 2

    errors = validate_manifest(manifest)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("manifest ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
