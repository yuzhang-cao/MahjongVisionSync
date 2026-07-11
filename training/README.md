# Training Dataset Manifest

This folder documents the training-data handoff contract. It does not contain
real datasets.

The current manifest schema is for object detection, not single-image
classification. Each manifest is JSON with:

- `schema_version`: currently `1`.
- `dataset_id`: stable dataset identifier.
- `tile_set_id`: `mcr_144_42` or `riichi_mleague_136_37`.
- `rules_profile`: `mcr` or `riichi_mleague`.
- `visual_domain`: must match the rules profile.
- `class_count`: `42` for MCR, `37` for M.League-style Riichi.
- `license` and `source`: required non-empty provenance fields.
- `images`: one object per image.

Each image entry includes:

- `image`: relative image path.
- `split`: `train`, `validation`, or `test`.
- `capture_group`: grouping key for related frames from one capture; a group
  must not appear in more than one split.
- `width` and `height`: positive source dimensions.
- `annotations`: one or more tile bounding boxes.

Each annotation includes:

- `class_id` and `code`: both must refer to the same class in the selected
  tile set.
- `bbox`: normalized `x`, `y`, `width`, `height`; width and height must be
  positive and the box must fit inside `[0, 1]`.

Validation command:

```bash
python3 -m tools.training_dataset.validate_manifest path/to/manifest.json
```

## Windows training environment

The Windows RTX node reuses the installed CUDA-enabled PyTorch build through a
project-local virtual environment:

```powershell
py -3.11 -m venv --system-site-packages .venv-training
.\.venv-training\Scripts\python.exe -m pip install -r training\requirements-windows.txt
.\.venv-training\Scripts\python.exe tools\training_environment_report.py --require-gpu --output training\reports\windows-environment.json
```

The pinned packages are training tools, not application runtime dependencies.
Ultralytics is distributed under AGPL-3.0; its use and generated model delivery
must remain recorded in the model manifest and third-party notices.

## Synthetic GPU smoke run

The smoke command creates colored rectangles and YOLO labels solely to verify
CUDA training and ONNX export. It is not a Mahjong accuracy run and its weights
must never replace an application model.

```powershell
.\.venv-training\Scripts\python.exe -m tools.run_training_smoke --profile mcr --device 0
```

Generated inputs are written below `training/smoke-data/`; run logs, weights,
metrics, and the ONNX file are written below `training/runs/`. Both directories
are intentionally ignored by Git. A successful run leaves a
`smoke-summary.json` file in its run directory.

The Windows node completed both the MCR 42-class and M.League Riichi 37-class
smoke runs on 2026-07-11 with an RTX 4060 Ti. The committed evidence files are:

- `training/reports/windows-environment.json`
- `training/reports/windows-smoke-mcr-20260711.json`
- `training/reports/windows-smoke-riichi-mleague-20260711.json`

The full ignored run directories remain on Windows at
`training/runs/smoke-mcr-20260711T121235Z` and
`training/runs/smoke-riichi_mleague-20260711T121525Z`. These reports prove that
CUDA training and ONNX export work; they do not report Mahjong recognition
quality.

Formal training remains blocked until self-captured MCR and Riichi manifests
pass validation and their image sources and licenses are approved.
