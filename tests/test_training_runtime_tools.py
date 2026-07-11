import json
import tempfile
import unittest
from pathlib import Path

from tools.run_training_smoke import create_synthetic_dataset
from tools.training_environment_report import build_report
from tools.training_dataset.categories import RULES_PROFILES


class TrainingRuntimeToolTests(unittest.TestCase):
    def test_environment_report_has_stable_shape(self):
        report = build_report()
        self.assertEqual(1, report["schema_version"])
        self.assertIn("python_version", report)
        self.assertIn("packages", report)
        self.assertIn("torch_gpu", report)
        self.assertIn("nvidia_smi", report)
        json.dumps(report)

    def test_synthetic_dataset_uses_full_mcr_class_map(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data_yaml = create_synthetic_dataset(root, "mcr", image_size=64)
            rendered = data_yaml.read_text(encoding="utf-8")
            self.assertIn("  41: 'chrysanthemum'", rendered)
            self.assertEqual(42, RULES_PROFILES["mcr"]["class_count"])
            self.assertTrue((root / "images" / "train" / "train_000.png").is_file())
            self.assertEqual(
                "0 0.5 0.5 0.5 0.5\n",
                (root / "labels" / "train" / "train_000.txt").read_text(encoding="utf-8"),
            )

    def test_synthetic_dataset_uses_full_riichi_class_map(self):
        with tempfile.TemporaryDirectory() as directory:
            data_yaml = create_synthetic_dataset(Path(directory), "riichi_mleague", image_size=64)
            rendered = data_yaml.read_text(encoding="utf-8")
            self.assertIn("  36: 'red_five_sou'", rendered)
            self.assertEqual(37, RULES_PROFILES["riichi_mleague"]["class_count"])


if __name__ == "__main__":
    unittest.main()
