"""Deterministic, time-step combat approximation for factory balance checks.

This intentionally models gameplay trends rather than Godot physics. Enemies travel
from an estimated edge distance, attack on individual cooldowns only after arrival,
and cease contributing damage immediately upon death. Area Pulse samples 55% of
nearby attackers on each pulse rather than hitting the full wave.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import statistics
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from automation.models.game_config import CanonicalGameConfig, validate_config


@dataclass(frozen=True)
class SimulationSettings:
    timestep: float = 0.1
    spawn_distance_min: float = 360.0
    spawn_distance_max: float = 620.0
    enemy_attack_range: float = 60.0
    enemy_attack_rate: float = 0.5
    area_hit_fraction: float = 0.55
    max_wave_seconds: float = 120.0
    minimum_median_wave: int = 2
    early_death_failure_rate: float = 0.60
    plateau_ratio: float = 1.20
    runaway_ratio: float = 3.0


@dataclass
class EnemyState:
    hp: float
    damage: float
    speed: float
    distance: float
    attack_remaining: float
    archetype: str
    boss: bool = False
    alive: bool = True
    arrived_at: float | None = None
    damage_dealt: float = 0.0


@dataclass
class RunState:
    health: float
    max_health: float
    damage: float
    base_damage: float
    attack_speed: float
    critical_chance: float
    critical_multiplier: float
    coins: int
    weapons: dict[str, dict[str, Any]]
    owned_weapons: set[str]
    coin_multiplier: float = 1.0
    companion: bool = False
    nova_damage: float = 0.0
    nova_radius: float = 145.0
    shield: float = 0.0
    shield_delay: float = 0.0
    upgrade_levels: dict[str, int] = field(default_factory=dict)
    upgrades_owned: list[str] = field(default_factory=list)


def percentile(values: list[int], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    index = (len(ordered) - 1) * fraction
    lower, upper = int(index), min(int(index) + 1, len(ordered) - 1)
    return round(ordered[lower] + (ordered[upper] - ordered[lower]) * (index - lower), 2)


def enemy_count(config: CanonicalGameConfig, wave: int) -> int:
    return max(1, math.ceil(config.waves.starting_enemy_count * config.waves.enemy_growth_per_wave ** (wave - 1)))


def choose_archetype(config: CanonicalGameConfig, wave: int, rng: random.Random) -> str:
    pools = [pool for pool in config.waves.spawn_pools if pool.min_wave <= wave]
    pool = pools[-1]
    roll = rng.random() * sum(entry.weight for entry in pool.entries)
    for entry in pool.entries:
        roll -= entry.weight
        if roll <= 0:
            return entry.id
    return pool.entries[-1].id


def new_run(config: CanonicalGameConfig) -> RunState:
    state = RunState(
        health=config.player.max_health,
        max_health=config.player.max_health,
        damage=config.player.damage,
        # Phase 2's projectile definition is authored around a 10-damage player.
        # Keep that reference fixed so a preset's higher base player damage and
        # later damage upgrades both affect simulated weapon damage.
        base_damage=config.player.reference_damage,
        attack_speed=config.player.attack_speed,
        critical_chance=config.player.critical_chance,
        critical_multiplier=config.player.critical_multiplier,
        coins=config.economy.starting_coins,
        weapons={name: definition.model_dump(mode="json") for name, definition in config.weapons.definitions.items()},
        owned_weapons={config.weapons.starting_weapon},
    )
    if config.gameplay.combat_style == "space": state.shield = 35.0
    return state


def eligible_upgrades(config: CanonicalGameConfig, state: RunState) -> list[Any]:
    result = []
    for upgrade in config.upgrades.definitions:
        if state.upgrade_levels.get(upgrade.id, 0) >= upgrade.max_level:
            continue
        if any(state.upgrade_levels.get(required, 0) == 0 for required in upgrade.prerequisites):
            continue
        if upgrade.category == "unlock" and upgrade.weapon in state.owned_weapons:
            continue
        if upgrade.category == "weapon" and upgrade.weapon not in state.owned_weapons:
            continue
        if upgrade.category == "companion" and state.companion:
            continue
        if upgrade.target == "heal_percent" and state.health >= state.max_health:
            continue
        result.append(upgrade)
    return result


def apply_upgrade(config: CanonicalGameConfig, state: RunState, rng: random.Random) -> None:
    eligible = eligible_upgrades(config, state)
    if not eligible:
        return
    choices = rng.sample(eligible, min(3, len(eligible)))
    upgrade = rng.choice(choices)
    value = upgrade.value or 0.0
    state.upgrade_levels[upgrade.id] = state.upgrade_levels.get(upgrade.id, 0) + 1
    state.upgrades_owned.append(upgrade.id)
    if upgrade.category == "unlock" and upgrade.weapon:
        state.owned_weapons.add(upgrade.weapon)
    elif upgrade.category == "player":
        if upgrade.target == "damage":
            state.damage += value
        elif upgrade.target == "attack_speed":
            state.attack_speed += value
        elif upgrade.target == "max_health":
            state.max_health += value
            state.health = min(state.max_health, state.health + value)
        elif upgrade.target == "critical_chance":
            state.critical_chance = min(1.0, state.critical_chance + value)
        elif upgrade.target == "critical_multiplier":
            state.critical_multiplier += value
    elif upgrade.category == "weapon" and upgrade.weapon:
        weapon = state.weapons[upgrade.weapon]
        weapon[upgrade.target] = max(0.08, weapon.get(upgrade.target, 0.0) + value) if upgrade.target == "cooldown" else weapon.get(upgrade.target, 0.0) + value
    elif upgrade.category == "utility" and upgrade.target == "heal_percent":
        state.health = min(state.max_health, state.health + state.max_health * value)
    elif upgrade.category == "utility" and upgrade.target == "coin_multiplier":
        state.coin_multiplier += value
    elif upgrade.category == "companion":
        state.companion = True
    elif upgrade.category == "special" and upgrade.target == "nova_damage":
        state.nova_damage += value
    elif upgrade.category == "special" and upgrade.target == "nova_radius":
        state.nova_radius += value


def award_kill(config: CanonicalGameConfig, state: RunState, enemy: EnemyState) -> None:
    base = math.floor(config.economy.coin_per_kill * config.enemies.archetypes[enemy.archetype].reward_multiplier + 0.5)
    if enemy.boss:
        base += config.economy.boss_coin_reward
    state.coins += math.floor(base * state.coin_multiplier + 0.5)


def spawn_wave(config: CanonicalGameConfig, wave: int, rng: random.Random, settings: SimulationSettings) -> list[EnemyState]:
    boss_wave = wave % config.bosses.every == 0
    count = config.bosses.additional_enemies if boss_wave else enemy_count(config, wave)
    entries: list[tuple[str, bool]] = [(config.bosses.archetype, True)] if boss_wave else []
    entries.extend((choose_archetype(config, wave, rng), False) for _ in range(count))
    spawned: list[EnemyState] = []
    for archetype_id, is_boss in entries:
        archetype = config.enemies.archetypes[archetype_id]
        hp = config.enemies.base.base_health * config.enemies.base.health_growth_per_wave ** (wave - 1) * archetype.health_multiplier
        damage = config.enemies.base.base_damage * config.enemies.base.damage_growth_per_wave ** (wave - 1) * archetype.damage_multiplier
        spawned.append(EnemyState(hp, damage, config.enemies.base.movement_speed * archetype.speed_multiplier, rng.uniform(settings.spawn_distance_min, settings.spawn_distance_max), rng.uniform(0.0, 1.0 / settings.enemy_attack_rate), archetype_id, is_boss))
    return spawned


def run_wave(config: CanonicalGameConfig, state: RunState, wave: int, rng: random.Random, settings: SimulationSettings) -> dict[str, Any]:
    enemies = spawn_wave(config, wave, rng, settings)
    start_health, elapsed, projectile_ready, pulse_ready = state.health, 0.0, 0.0, 0.0
    companion_ready, nova_ready = 0.0, 0.0
    pending_hits: list[tuple[float, EnemyState, float]] = []
    coins_before, total_damage_taken = state.coins, 0.0
    boss = any(enemy.boss for enemy in enemies)
    boss_ttk: float | None = None
    boss_damage = 0.0
    while elapsed < settings.max_wave_seconds and state.health > 0 and any(enemy.alive for enemy in enemies):
        state.shield_delay = max(0.0, state.shield_delay - settings.timestep)
        if config.gameplay.combat_style == "space" and state.shield_delay <= 0:
            state.shield = min(35.0, state.shield + settings.timestep * 7.0)
        for impact_time, target, damage in pending_hits[:]:
            if impact_time <= elapsed:
                pending_hits.remove((impact_time, target, damage))
                if target.alive:
                    target.hp -= damage
                    if target.hp <= 0:
                        target.alive = False
                        award_kill(config, state, target)
                        if target.boss:
                            boss_ttk = elapsed
        living = [enemy for enemy in enemies if enemy.alive]
        for enemy in living:
            enemy.distance = max(0.0, enemy.distance - enemy.speed * settings.timestep)
            if enemy.arrived_at is None and enemy.distance <= settings.enemy_attack_range:
                enemy.arrived_at = elapsed
            if enemy.arrived_at is not None:
                enemy.attack_remaining -= settings.timestep
                if enemy.attack_remaining <= 0.0:
                    incoming = enemy.damage
                    if config.gameplay.combat_style == "space":
                        state.shield_delay = 7.0
                        absorbed = min(state.shield, incoming)
                        state.shield -= absorbed
                        incoming -= absorbed
                    state.health -= incoming
                    total_damage_taken += incoming
                    enemy.damage_dealt += incoming
                    if enemy.boss:
                        boss_damage += incoming
                    enemy.attack_remaining += 1.0 / settings.enemy_attack_rate
        if elapsed >= projectile_ready:
            targets = [enemy for enemy in enemies if enemy.alive and enemy.distance <= state.weapons[config.weapons.starting_weapon]["range"]]
            if targets:
                target = min(targets, key=lambda enemy: enemy.distance)
                weapon = state.weapons[config.weapons.starting_weapon]
                damage = weapon["damage"] * state.damage / state.base_damage
                if config.gameplay.combat_style == "space": damage *= 2.1
                if rng.random() < state.critical_chance:
                    damage *= state.critical_multiplier
                pending_hits.append((elapsed + target.distance / weapon["projectile_speed"], target, damage))
                projectile_ready = elapsed + max(0.08, weapon["cooldown"] / state.attack_speed)
        if "area_pulse" in state.owned_weapons and elapsed >= pulse_ready:
            pulse = state.weapons["area_pulse"]
            for enemy in enemies:
                if enemy.alive and enemy.arrived_at is not None and rng.random() < settings.area_hit_fraction:
                    damage = pulse["damage"] * state.damage / state.base_damage
                    if rng.random() < state.critical_chance:
                        damage *= state.critical_multiplier
                    enemy.hp -= damage
                    if enemy.hp <= 0:
                        enemy.alive = False
                        award_kill(config, state, enemy)
                        if enemy.boss:
                            boss_ttk = elapsed
            pulse_ready = elapsed + max(0.08, pulse["cooldown"] / state.attack_speed)
        if state.companion and elapsed >= companion_ready:
            targets = [enemy for enemy in enemies if enemy.alive and enemy.distance <= 320.0]
            if targets:
                target = min(targets, key=lambda enemy: enemy.distance)
                target.hp -= max(1.0, state.damage * 0.45)
                if target.hp <= 0:
                    target.alive = False
                    award_kill(config, state, target)
                    if target.boss: boss_ttk = elapsed
                companion_ready = elapsed + 1.1
        if state.nova_damage > 0 and elapsed >= nova_ready:
            radius = state.nova_radius * (0.5 if config.gameplay.combat_style == "ninja" else 1.0)
            for enemy in enemies:
                if enemy.alive and enemy.distance <= radius:
                    enemy.hp -= state.nova_damage
                    if enemy.hp <= 0:
                        enemy.alive = False
                        award_kill(config, state, enemy)
                        if enemy.boss: boss_ttk = elapsed
            nova_ready = elapsed + (6.0 if config.gameplay.combat_style == "ninja" else 12.0)
        elapsed += settings.timestep
    living = [enemy for enemy in enemies if enemy.alive]
    first_arrival = min((enemy.arrived_at for enemy in enemies if enemy.arrived_at is not None), default=None)
    killed = len(enemies) - len(living)
    return {
        "completed": not living and state.health > 0,
        "died": state.health <= 0,
        "wave": wave,
        "enemies_spawned": len(enemies),
        "enemies_killed": killed,
        "player_starting_hp": round(start_health, 2),
        "player_ending_hp": round(max(0.0, state.health), 2),
        "player_dps": round(state.weapons[config.weapons.starting_weapon]["damage"] * state.damage / state.base_damage / (state.weapons[config.weapons.starting_weapon]["cooldown"] / state.attack_speed), 2),
        "effective_incoming_dps": round(total_damage_taken / max(elapsed, settings.timestep), 2),
        "time_before_first_enemy_reaches_player": round(first_arrival, 2) if first_arrival is not None else None,
        "wave_duration": round(elapsed, 2),
        "coins_earned": state.coins - coins_before,
        "boss": boss,
        "boss_time_to_kill": round(boss_ttk, 2) if boss_ttk is not None else None,
        "boss_outgoing_damage": round(boss_damage, 2),
        "upgrades_owned": list(state.upgrades_owned),
    }


def classify(report: dict[str, Any], settings: SimulationSettings) -> str:
    if report["median_wave"] < settings.minimum_median_wave or report["death_probability_by_wave"].get("1", 0.0) >= settings.early_death_failure_rate:
        return "FAIL"
    return "WARN" if report["warnings"] else "PASS"


def simulate(config_data: dict[str, Any], runs: int = 1000, seed: int = 0, max_waves: int = 30, settings: SimulationSettings | None = None) -> dict[str, Any]:
    if runs < 1:
        raise ValueError("runs must be positive")
    config, settings = validate_config(config_data), settings or SimulationSettings()
    rng = random.Random(seed)
    reached, coins, survival = [], [], []
    samples: dict[int, list[dict[str, Any]]] = {wave: [] for wave in range(1, max_waves + 1)}
    death_waves: list[int] = []
    for _ in range(runs):
        state, elapsed, completed = new_run(config), 0.0, 0
        for wave in range(1, max_waves + 1):
            metric = run_wave(config, state, wave, rng, settings)
            samples[wave].append(metric)
            elapsed += metric["wave_duration"]
            if not metric["completed"]:
                death_waves.append(wave)
                break
            completed = wave
            apply_upgrade(config, state, rng)
        reached.append(completed)
        coins.append(state.coins)
        survival.append(elapsed)
    wave_metrics = []
    for wave, rows in samples.items():
        if not rows:
            continue
        entered = len(rows)
        completed_rows = [row for row in rows if row["completed"]]
        wave_metrics.append({
            "wave": wave,
            "enemies_spawned": round(statistics.mean(row["enemies_spawned"] for row in rows), 2),
            "enemies_killed": round(statistics.mean(row["enemies_killed"] for row in rows), 2),
            "player_starting_hp": round(statistics.mean(row["player_starting_hp"] for row in rows), 2),
            "player_ending_hp": round(statistics.mean(row["player_ending_hp"] for row in rows), 2),
            "player_dps": round(statistics.mean(row["player_dps"] for row in rows), 2),
            "effective_incoming_dps": round(statistics.mean(row["effective_incoming_dps"] for row in rows), 2),
            "time_before_first_enemy_reaches_player": round(statistics.mean(row["time_before_first_enemy_reaches_player"] or 0 for row in rows), 2),
            "wave_duration": round(statistics.mean(row["wave_duration"] for row in rows), 2),
            "coins_earned": round(statistics.mean(row["coins_earned"] for row in rows), 2),
            "boss": rows[0]["boss"],
            "boss_time_to_kill": round(statistics.mean([row["boss_time_to_kill"] for row in completed_rows if row["boss_time_to_kill"] is not None]), 2) if any(row["boss_time_to_kill"] is not None for row in completed_rows) else None,
            "boss_outgoing_damage": round(statistics.mean(row["boss_outgoing_damage"] for row in rows), 2),
            "survival_rate": round(len(completed_rows) / entered, 4),
            "death_probability": round(1.0 - len(completed_rows) / entered, 4),
            "average_upgrade_count": round(statistics.mean(len(row["upgrades_owned"]) for row in rows), 2),
        })
    warnings: list[str] = []
    if wave_metrics and wave_metrics[0]["survival_rate"] < 1.0 - settings.early_death_failure_rate:
        warnings.append("most simulated runs die in wave 1")
    for previous, current in zip(wave_metrics, wave_metrics[1:]):
        if current["effective_incoming_dps"] > max(1.0, previous["effective_incoming_dps"]) * 1.8:
            warnings.append("first major difficulty spike near wave %d" % current["wave"])
            break
    if len(wave_metrics) >= 6:
        early_dps, late_dps = wave_metrics[0]["player_dps"], wave_metrics[min(10, len(wave_metrics) - 1)]["player_dps"]
        early_pressure, late_pressure = wave_metrics[0]["effective_incoming_dps"], wave_metrics[min(10, len(wave_metrics) - 1)]["effective_incoming_dps"]
        if late_dps <= early_dps * settings.plateau_ratio:
            warnings.append("player DPS progression stalls after wave %d" % wave_metrics[min(10, len(wave_metrics) - 1)]["wave"])
        if late_pressure > max(1.0, early_pressure) * settings.runaway_ratio and late_pressure / max(late_dps, 0.01) > early_pressure / max(early_dps, 0.01):
            warnings.append("enemy scaling runaway: pressure grows >3x faster than player power")
    for index, row in enumerate(wave_metrics):
        if row["boss"] and index > 0 and row["effective_incoming_dps"] < wave_metrics[index - 1]["effective_incoming_dps"] * 0.5:
            warnings.append("boss pressure is inverted near wave %d" % row["wave"])
            break
    death_probability = {str(wave): round(death_waves.count(wave) / runs, 4) for wave in range(1, max_waves + 1) if death_waves.count(wave)}
    most_common_death = max(set(death_waves), key=death_waves.count) if death_waves else None
    wall = next((row["wave"] for row in wave_metrics if row["survival_rate"] < 0.5), None)
    report = {
        "runs": runs,
        "seed": seed,
        "average_wave": round(statistics.mean(reached), 2),
        "median_wave": statistics.median(reached),
        "p25_wave": percentile(reached, 0.25),
        "p75_wave": percentile(reached, 0.75),
        "p90_wave": percentile(reached, 0.90),
        "average_survival_time": round(statistics.mean(survival), 2),
        "average_coins": round(statistics.mean(coins), 2),
        "most_common_death_wave": most_common_death,
        "first_major_difficulty_spike": next((warning for warning in warnings if warning.startswith("first major")), None),
        "progression_wall_estimate": wall,
        "death_probability_by_wave": death_probability,
        "warnings": warnings,
        "wave_metrics": wave_metrics,
    }
    report["balance_status"] = classify(report, settings)
    report["unsupported_effects"] = []
    report["model_limitations"] = ["Approximation models arithmetic, ownership, companion, special and rewards, but not exact 2D collision paths or telegraph dodging.", "Use engine_balance and physical playtests for release decisions."]
    report["release_gate"] = "DIAGNOSTIC_ONLY"
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()
    try:
        report = simulate(json.loads(args.config.read_text(encoding="utf-8")), args.runs, args.seed)
        output = args.config.parent / "balance_report.json"
        output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("Balance: %s" % report["balance_status"])
        print("Average wave: %s" % report["average_wave"])
        print("Median wave: %s" % report["median_wave"])
        print("Average coins: %s" % report["average_coins"])
        print("Warnings: %d" % len(report["warnings"]))
        print("Report: %s" % output)
        return 0
    except (OSError, ValueError) as error:
        print("Simulation failed: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
