from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from random import Random

from automation.generators.generate_game import ROOT, config_hash, deep_merge, generate_variant, read_json
from automation.models.game_config import validate_config
from automation.simulation.simulate_balance import SimulationSettings, apply_upgrade, new_run, run_wave, simulate, spawn_wave


def base_config() -> dict:
    return read_json(ROOT / "configs" / "templates" / "baseSurvivor.json")


class FactoryTests(unittest.TestCase):
    def test_valid_config_passes(self) -> None:
        self.assertEqual(validate_config(base_config()).metadata.id, "baseSurvivor")

    def test_missing_required_config_fails(self) -> None:
        config = base_config()
        del config["player"]
        with self.assertRaises(ValueError):
            validate_config(config)

    def test_invalid_starting_weapon_fails(self) -> None:
        config = base_config()
        config["weapons"]["starting_weapon"] = "missing"
        with self.assertRaises(ValueError):
            validate_config(config)

    def test_invalid_enemy_reference_fails(self) -> None:
        config = base_config()
        config["waves"]["spawn_pools"][0]["entries"][0]["id"] = "missing"
        with self.assertRaises(ValueError):
            validate_config(config)

    def test_invalid_upgrade_target_and_negative_health_fail(self) -> None:
        config = base_config()
        config["upgrades"]["definitions"][0]["target"] = "not_a_stat"
        with self.assertRaises(ValueError):
            validate_config(config)
        config = base_config()
        config["player"]["max_health"] = -1
        with self.assertRaises(ValueError):
            validate_config(config)

    def test_deep_merge_is_predictable(self) -> None:
        merged = deep_merge({"a": {"b": 1, "c": [1]}, "d": 1}, {"a": {"b": 2, "c": [2]}, "d": 3})
        self.assertEqual(merged, {"a": {"b": 2, "c": [2]}, "d": 3})

    def test_seed_and_hash_are_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            _, first, _ = generate_variant("spaceSurvivor", 12345, output, activate=False)
            _, second, _ = generate_variant("spaceSurvivor", 12345, output, activate=False)
            values = {generate_variant("spaceSurvivor", seed, output, activate=False)[1]["player"]["damage"] for seed in range(16)}
        self.assertEqual(first, second)
        self.assertEqual(config_hash(first), config_hash(second))
        self.assertGreater(len(values), 1)

    def test_simulator_returns_report(self) -> None:
        report = simulate(base_config(), runs=10, seed=7, max_waves=5)
        self.assertEqual(report["runs"], 10)
        self.assertIn("average_wave", report)
        self.assertGreaterEqual(len(report["wave_metrics"]), 1)
        self.assertIn(report["balance_status"], {"PASS", "WARN", "FAIL"})
        self.assertEqual(report["release_gate"], "DIAGNOSTIC_ONLY")
        self.assertEqual(report["unsupported_effects"], [])

    def test_enemies_do_not_damage_before_travel_time(self) -> None:
        config = validate_config(base_config())
        state = new_run(config)
        result = run_wave(config, state, 1, Random(1), SimulationSettings(spawn_distance_min=1000, spawn_distance_max=1000, max_wave_seconds=1))
        self.assertEqual(result["player_starting_hp"], result["player_ending_hp"])
        self.assertIsNone(result["time_before_first_enemy_reaches_player"])

    def test_dead_enemies_stop_dealing_damage(self) -> None:
        source = base_config()
        source["player"]["damage"] = 10000
        source["waves"]["starting_enemy_count"] = 1
        config = validate_config(source)
        state = new_run(config)
        result = run_wave(config, state, 1, Random(2), SimulationSettings(spawn_distance_min=120, spawn_distance_max=120))
        self.assertEqual(result["enemies_killed"], result["enemies_spawned"])
        self.assertEqual(result["boss_outgoing_damage"], 0.0)
        self.assertEqual(result["player_starting_hp"], result["player_ending_hp"])

    def test_fast_enemy_reaches_sooner(self) -> None:
        config = validate_config(base_config())
        normal = config.enemies.archetypes["normal"]
        fast = config.enemies.archetypes["fast"]
        base_speed = config.enemies.base.movement_speed
        self.assertLess((500 - 60) / (base_speed * fast.speed_multiplier), (500 - 60) / (base_speed * normal.speed_multiplier))

    def test_damage_and_health_improve_progression(self) -> None:
        baseline = simulate(base_config(), runs=100, seed=3, max_waves=10)
        high_damage = base_config()
        high_damage["player"]["damage"] = 20
        high_health = base_config()
        high_health["player"]["max_health"] = 200
        self.assertGreaterEqual(simulate(high_damage, runs=100, seed=3, max_waves=10)["average_wave"], baseline["average_wave"])
        self.assertGreaterEqual(simulate(high_health, runs=100, seed=3, max_waves=10)["average_wave"], baseline["average_wave"])

    def test_upgrade_selection_changes_run_state(self) -> None:
        source = base_config()
        source["upgrades"]["definitions"] = [source["upgrades"]["definitions"][0]]
        config = validate_config(source)
        state = new_run(config)
        apply_upgrade(config, state, Random(4))
        self.assertGreater(state.damage, config.player.damage)

    def test_simulation_is_seed_deterministic(self) -> None:
        first = simulate(base_config(), runs=30, seed=9, max_waves=8)
        second = simulate(base_config(), runs=30, seed=9, max_waves=8)
        self.assertEqual(first, second)

    def test_every_preset_generates_a_valid_non_failing_variant(self) -> None:
        presets = sorted((ROOT / "configs" / "presets").glob("*.json"))
        self.assertGreater(len(presets), 0)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            for preset in presets:
                _, config, _ = generate_variant(preset.stem, 12345, output, activate=False)
                self.assertEqual(validate_config(config).metadata.id, config["metadata"]["id"])
                self.assertNotEqual(simulate(config, runs=30, seed=12345, max_waves=8)["balance_status"], "FAIL")

    def test_boss_and_coins_are_reported_from_actual_kills(self) -> None:
        source = base_config()
        source["player"]["damage"] = 10000
        report = simulate(source, runs=5, seed=1, max_waves=5)
        boss_row = next(row for row in report["wave_metrics"] if row["wave"] == 5)
        self.assertTrue(boss_row["boss"])
        self.assertIsNotNone(boss_row["boss_time_to_kill"])
        self.assertGreater(boss_row["coins_earned"], 0)

    def test_pathological_wave_one_death_fails(self) -> None:
        source = base_config()
        source["player"]["max_health"] = 1
        source["enemies"]["base"]["base_damage"] = 100
        report = simulate(source, runs=20, seed=1, max_waves=3, settings=SimulationSettings(spawn_distance_min=61, spawn_distance_max=61))
        self.assertEqual(report["balance_status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
