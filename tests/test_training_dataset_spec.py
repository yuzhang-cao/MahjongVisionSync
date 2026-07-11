import json
import subprocess
import sys
import unittest
from pathlib import Path

from tools.training_dataset import categories
from tools.training_dataset.validator import validate_manifest


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "training_dataset"


class TrainingDatasetSpecTests(unittest.TestCase):
    def test_mcr_mapping_has_42_visual_classes_with_distinct_flowers(self):
        self.assertEqual(42, len(categories.MCR_CLASSES))
        flower_codes = {"spring", "summer", "autumn", "winter", "plum", "orchid", "bamboo", "chrysanthemum"}
        self.assertTrue(flower_codes.issubset({item["code"] for item in categories.MCR_CLASSES}))

    def test_riichi_mapping_has_37_visual_classes_with_red_fives(self):
        self.assertEqual(37, len(categories.RIICHI_MLEAGUE_CLASSES))
        red_fives = {"red_five_man", "red_five_pin", "red_five_sou"}
        self.assertTrue(red_fives.issubset({item["code"] for item in categories.RIICHI_MLEAGUE_CLASSES}))

    def test_valid_manifest_passes_schema_validation(self):
        manifest = json.loads((FIXTURES / "valid_mcr_manifest.json").read_text(encoding="utf-8"))
        errors = validate_manifest(manifest)
        self.assertEqual([], errors)

    def test_invalid_manifest_reports_errors(self):
        manifest = json.loads((FIXTURES / "invalid_manifest.json").read_text(encoding="utf-8"))
        errors = validate_manifest(manifest)
        self.assertGreaterEqual(len(errors), 3)
        self.assertTrue(any("rules_profile" in error for error in errors))
        self.assertTrue(any("images" in error or "annotations" in error for error in errors))
        self.assertTrue(any("capture_group" in error for error in errors))

    def test_python_and_swift_tile_codes_are_aligned(self):
        swift_source = (ROOT / "MahjongTing" / "Match" / "MatchContracts.swift").read_text(encoding="utf-8")
        for item in categories.MCR_CLASSES + categories.RIICHI_RED_FIVE_CLASSES:
            self.assertIn(f'= "{item["code"]}"', swift_source)

    def test_class_id_and_code_must_match(self):
        manifest = json.loads((FIXTURES / "valid_riichi_manifest.json").read_text(encoding="utf-8"))
        manifest["images"][0]["annotations"][0]["class_id"] = 0
        errors = validate_manifest(manifest)
        self.assertTrue(any("class_id and code" in error for error in errors))

    def test_capture_group_cannot_cross_splits(self):
        manifest = json.loads((FIXTURES / "valid_mcr_manifest.json").read_text(encoding="utf-8"))
        manifest["images"][1]["capture_group"] = manifest["images"][0]["capture_group"]
        errors = validate_manifest(manifest)
        self.assertTrue(any("capture_group" in error and "appears in both" in error for error in errors))

    def test_bbox_must_be_normalized_and_positive(self):
        manifest = json.loads((FIXTURES / "valid_mcr_manifest.json").read_text(encoding="utf-8"))
        manifest["images"][0]["annotations"][0]["bbox"]["width"] = 0
        errors = validate_manifest(manifest)
        self.assertTrue(any("bbox.width must be positive" in error for error in errors))

    def test_cli_accepts_valid_manifest_and_rejects_invalid_manifest(self):
        valid = subprocess.run(
            [sys.executable, "-m", "tools.training_dataset.validate_manifest", str(FIXTURES / "valid_riichi_manifest.json")],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, valid.returncode, valid.stderr)

        invalid = subprocess.run(
            [sys.executable, "-m", "tools.training_dataset.validate_manifest", str(FIXTURES / "invalid_manifest.json")],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertNotEqual(0, invalid.returncode)


if __name__ == "__main__":
    unittest.main()
