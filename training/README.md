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
