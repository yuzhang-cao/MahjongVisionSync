"""Dataset manifest validation for MahjongVisionSync training data."""

from __future__ import annotations

from collections.abc import Mapping
from math import isfinite

from .categories import RULES_PROFILES, class_by_code, class_by_id


REQUIRED_SPLITS = ("train", "validation", "test")


def validate_manifest(manifest: Mapping) -> list[str]:
    errors: list[str] = []
    if not isinstance(manifest, Mapping):
        return ["manifest must be a JSON object"]

    if manifest.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    _validate_required_string(manifest, "dataset_id", errors)
    _validate_required_string(manifest, "license", errors)
    _validate_required_string(manifest, "source", errors)

    rules_profile = manifest.get("rules_profile")
    if rules_profile not in RULES_PROFILES:
        errors.append("rules_profile must be one of: " + ", ".join(sorted(RULES_PROFILES)))
        expected = None
    else:
        expected = RULES_PROFILES[rules_profile]

    visual_domain = manifest.get("visual_domain")
    if expected is not None and visual_domain != expected["visual_domain"]:
        errors.append(f"visual_domain must be {expected['visual_domain']} for {rules_profile}")

    tile_set_id = manifest.get("tile_set_id")
    if expected is not None and tile_set_id != expected["tile_set_id"]:
        errors.append(f"tile_set_id must be {expected['tile_set_id']} for {rules_profile}")

    class_count = manifest.get("class_count")
    if expected is not None and class_count != expected["class_count"]:
        errors.append(f"class_count must be {expected['class_count']} for {rules_profile}")

    _validate_images(manifest.get("images"), rules_profile, errors)
    return errors


def _validate_required_string(manifest: Mapping, key: str, errors: list[str]) -> None:
    value = manifest.get(key)
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{key} must be a non-empty string")


def _validate_images(images, rules_profile, errors: list[str]) -> None:
    if not isinstance(images, list) or not images:
        errors.append("images must be a non-empty list")
        return
    by_id = class_by_id(rules_profile) if rules_profile in RULES_PROFILES else {}
    by_code = class_by_code(rules_profile) if rules_profile in RULES_PROFILES else {}
    split_groups: dict[str, set[str]] = {split: set() for split in REQUIRED_SPLITS}
    group_to_split: dict[str, str] = {}
    seen_image_paths: set[str] = set()

    for index, image in enumerate(images):
        prefix = f"images[{index}]"
        if not isinstance(image, Mapping):
            errors.append(f"{prefix} must be an object")
            continue
        path = image.get("image")
        if not isinstance(path, str) or not path.strip():
            errors.append(f"{prefix}.image must be a non-empty string")
        elif path in seen_image_paths:
            errors.append(f"{prefix}.image is duplicated: {path}")
        else:
            seen_image_paths.add(path)

        split = image.get("split")
        if split not in REQUIRED_SPLITS:
            errors.append(f"{prefix}.split must be one of: {', '.join(REQUIRED_SPLITS)}")
        capture_group = image.get("capture_group")
        if not isinstance(capture_group, str) or not capture_group.strip():
            errors.append(f"{prefix}.capture_group must be a non-empty string")
        elif split in REQUIRED_SPLITS:
            previous_split = group_to_split.get(capture_group)
            if previous_split is not None and previous_split != split:
                errors.append(f"capture_group {capture_group} appears in both {previous_split} and {split}")
            group_to_split[capture_group] = split
            split_groups[split].add(capture_group)

        _validate_positive_integer(image.get("width"), f"{prefix}.width", errors)
        _validate_positive_integer(image.get("height"), f"{prefix}.height", errors)
        _validate_annotations(image.get("annotations"), by_id, by_code, prefix, errors)

    for split in REQUIRED_SPLITS:
        if not split_groups[split]:
            errors.append(f"split {split} must contain at least one capture_group")


def _validate_positive_integer(value, field: str, errors: list[str]) -> None:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        errors.append(f"{field} must be a positive integer")


def _validate_annotations(annotations, by_id, by_code, prefix: str, errors: list[str]) -> None:
    if not isinstance(annotations, list) or not annotations:
        errors.append(f"{prefix}.annotations must be a non-empty list")
        return
    for index, annotation in enumerate(annotations):
        ann_prefix = f"{prefix}.annotations[{index}]"
        if not isinstance(annotation, Mapping):
            errors.append(f"{ann_prefix} must be an object")
            continue
        class_id = annotation.get("class_id")
        code = annotation.get("code")
        if not isinstance(class_id, int) or isinstance(class_id, bool):
            errors.append(f"{ann_prefix}.class_id must be an integer")
        if not isinstance(code, str) or not code.strip():
            errors.append(f"{ann_prefix}.code must be a non-empty string")

        expected_by_id = by_id.get(class_id)
        expected_by_code = by_code.get(code)
        if isinstance(class_id, int) and not isinstance(class_id, bool) and expected_by_id is None:
            errors.append(f"{ann_prefix}.class_id is not valid: {class_id}")
        if isinstance(code, str) and code and expected_by_code is None:
            errors.append(f"{ann_prefix}.code is not valid: {code}")
        if expected_by_id is not None and expected_by_code is not None and expected_by_id["code"] != code:
            errors.append(f"{ann_prefix}.class_id and code do not refer to the same class")

        _validate_bbox(annotation.get("bbox"), ann_prefix, errors)


def _validate_bbox(bbox, prefix: str, errors: list[str]) -> None:
    if not isinstance(bbox, Mapping):
        errors.append(f"{prefix}.bbox must be an object")
        return
    for key in ("x", "y", "width", "height"):
        value = bbox.get(key)
        if not _is_finite_number(value):
            errors.append(f"{prefix}.bbox.{key} must be a finite number")
            continue
        if key in ("width", "height"):
            if value <= 0:
                errors.append(f"{prefix}.bbox.{key} must be positive")
        elif value < 0:
            errors.append(f"{prefix}.bbox.{key} must be non-negative")
    x = bbox.get("x")
    y = bbox.get("y")
    width = bbox.get("width")
    height = bbox.get("height")
    if all(_is_finite_number(value) for value in (x, y, width, height)):
        if x + width > 1 or y + height > 1:
            errors.append(f"{prefix}.bbox must fit inside normalized image bounds")


def _is_finite_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and isfinite(value)
