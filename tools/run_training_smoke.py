#!/usr/bin/env python3
"""Run a tiny synthetic YOLO train/export cycle on the configured device."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from tools.training_dataset.categories import RULES_PROFILES


def yaml_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def create_synthetic_dataset(root: Path, profile: str, image_size: int = 128) -> Path:
    from PIL import Image, ImageDraw

    profile_data = RULES_PROFILES[profile]
    classes = profile_data["classes"]
    for split, count in (("train", 8), ("val", 4)):
        image_dir = root / "images" / split
        label_dir = root / "labels" / split
        image_dir.mkdir(parents=True, exist_ok=True)
        label_dir.mkdir(parents=True, exist_ok=True)
        for index in range(count):
            class_id = index % min(4, len(classes))
            image = Image.new("RGB", (image_size, image_size), color=(24, 30, 36))
            draw = ImageDraw.Draw(image)
            inset = image_size // 4
            draw.rectangle(
                (inset, inset, image_size - inset, image_size - inset),
                fill=(210, 225 - index * 5, 180 + index * 5),
                outline=(255, 255, 255),
                width=2,
            )
            stem = f"{split}_{index:03d}"
            image.save(image_dir / f"{stem}.png")
            (label_dir / f"{stem}.txt").write_text(
                f"{class_id} 0.5 0.5 0.5 0.5\n",
                encoding="utf-8",
            )

    yaml_lines = [
        f"path: {yaml_quote(root.resolve().as_posix())}",
        "train: images/train",
        "val: images/val",
        "names:",
    ]
    yaml_lines.extend(f"  {item['id']}: {yaml_quote(item['code'])}" for item in classes)
    data_yaml = root / "data.yaml"
    data_yaml.write_text("\n".join(yaml_lines) + "\n", encoding="utf-8")
    return data_yaml


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=sorted(RULES_PROFILES), default="mcr")
    parser.add_argument("--device", default="0", help="Ultralytics device, for example 0 or cpu")
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--imgsz", type=int, default=128)
    parser.add_argument("--batch", type=int, default=2)
    parser.add_argument("--smoke-root", type=Path, default=Path("training/smoke-data"))
    parser.add_argument("--runs-root", type=Path, default=Path("training/runs"))
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.epochs <= 0 or args.imgsz <= 0 or args.batch <= 0:
        raise SystemExit("epochs, imgsz, and batch must be positive")

    try:
        import torch
        import ultralytics
        from ultralytics import YOLO
    except ImportError as error:
        raise SystemExit(f"training dependency missing: {error}") from error

    if args.device != "cpu" and not torch.cuda.is_available():
        raise SystemExit("CUDA training was requested but torch.cuda.is_available() is false")

    run_id = datetime.now(timezone.utc).strftime(f"smoke-{args.profile}-%Y%m%dT%H%M%SZ")
    dataset_root = args.smoke_root / run_id
    data_yaml = create_synthetic_dataset(dataset_root, args.profile, args.imgsz)
    args.runs_root.mkdir(parents=True, exist_ok=True)

    model = YOLO("yolo11n.yaml")
    model.train(
        data=str(data_yaml),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        workers=0,
        project=str(args.runs_root.resolve()),
        name=run_id,
        exist_ok=False,
        pretrained=False,
        seed=0,
        deterministic=True,
        amp=False,
        plots=False,
        cache=False,
        verbose=True,
    )
    run_dir = Path(model.trainer.save_dir)
    best_weights = run_dir / "weights" / "best.pt"
    if not best_weights.is_file():
        raise SystemExit(f"training completed without best weights: {best_weights}")

    export_model = YOLO(str(best_weights))
    onnx_path = Path(
        export_model.export(
            format="onnx",
            imgsz=args.imgsz,
            dynamic=False,
            simplify=False,
            device="cpu",
        )
    )
    summary = {
        "schema_version": 1,
        "synthetic_only": True,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "profile": args.profile,
        "class_count": RULES_PROFILES[args.profile]["class_count"],
        "epochs": args.epochs,
        "imgsz": args.imgsz,
        "batch": args.batch,
        "device": args.device,
        "torch_version": torch.__version__,
        "ultralytics_version": ultralytics.__version__,
        "gpu_name": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
        "best_weights": str(best_weights.resolve()),
        "onnx_model": str(onnx_path.resolve()),
    }
    summary_path = run_dir / "smoke-summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
