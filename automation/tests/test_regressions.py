import copy
import tempfile
import unittest
from pathlib import Path

from automation.generators.generate_game import generate_variant
from automation.models.game_config import validate_config
from automation.qa.run_engine import errors
from automation.tests.test_factory import base_config
from automation.simulation.simulate_balance import enemy_count

class RegressionTests(unittest.TestCase):
    def test_script_error_cannot_hide_behind_zero_exit(self):
        self.assertTrue(errors("SCRIPT ERROR: bad resource"))
        self.assertTrue(errors("ERROR: missing file"))
        self.assertFalse(errors("ERROR: Failed to read the root certificate store."))

    def test_path_traversal_rejected_before_writes(self):
        with self.assertRaises(ValueError): generate_variant("../../escape", 1)

    def test_dependency_cycle_rejected(self):
        config = base_config()
        a, b = config["upgrades"]["definitions"][:2]
        a["prerequisites"] = [b["id"]]
        b["prerequisites"] = [a["id"]]
        with self.assertRaises(ValueError): validate_config(config)

    def test_weapon_target_pairing_rejected(self):
        config = base_config()
        upgrade = next(u for u in config["upgrades"]["definitions"] if u.get("target") == "projectile_speed")
        upgrade["target"] = "radius"
        with self.assertRaises(ValueError): validate_config(config)

    def test_positive_count_uses_ceil(self):
        config = base_config()
        config["waves"]["starting_enemy_count"] = 4
        config["waves"]["enemy_growth_per_wave"] = 1.1
        self.assertEqual(enemy_count(validate_config(config), 2), 5)

    def test_generate_default_does_not_activate(self):
        from automation.generators.generate_game import ROOT
        active = ROOT / "godot/masterGame/configs/active_game.json"
        before = active.read_bytes() if active.exists() else None
        with tempfile.TemporaryDirectory() as folder: generate_variant("spaceSurvivor", 7, Path(folder))
        self.assertEqual(active.read_bytes() if active.exists() else None, before)
