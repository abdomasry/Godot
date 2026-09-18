from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class MetadataConfig(StrictModel):
    id: str = Field(min_length=1, pattern=r"^[a-z][A-Za-z0-9_]*$")
    display_name: str = Field(min_length=1)
    version: str = Field(min_length=1)


class ThemeConfig(StrictModel):
    id: str = Field(min_length=1)
    display_name: str = Field(min_length=1)
    environment: str = "arena"


class TerminologyConfig(StrictModel):
    soft_currency_name: str = "Coins"
    premium_currency_name: str = "Gems"
    player_name: str = "Player"
    enemy_name: str = "Enemy"


class PlayerConfig(StrictModel):
    reference_damage: float = Field(default=10.0, gt=0)
    max_health: float = Field(gt=0)
    damage: float = Field(gt=0)
    attack_speed: float = Field(gt=0)
    movement_speed: float = Field(ge=0)
    critical_chance: float = Field(ge=0, le=1)
    critical_multiplier: float = Field(ge=1)


class WeaponDefinition(StrictModel):
    type: Literal["projectile", "area"]
    damage: float = Field(gt=0)
    cooldown: float = Field(gt=0)
    projectile_speed: float | None = Field(default=None, gt=0)
    range: float | None = Field(default=None, gt=0)
    radius: float | None = Field(default=None, gt=0)

    @model_validator(mode="after")
    def validate_type_fields(self) -> "WeaponDefinition":
        if self.type == "projectile" and (self.projectile_speed is None or self.range is None):
            raise ValueError("projectile weapons require projectile_speed and range")
        if self.type == "area" and self.radius is None:
            raise ValueError("area weapons require radius")
        return self


class WeaponsConfig(StrictModel):
    starting_weapon: str
    definitions: dict[str, WeaponDefinition] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_starting_weapon(self) -> "WeaponsConfig":
        if self.starting_weapon not in self.definitions:
            raise ValueError("starting_weapon must reference weapons.definitions")
        return self


class EnemyBaseConfig(StrictModel):
    base_health: float = Field(gt=0)
    base_damage: float = Field(ge=0)
    movement_speed: float = Field(ge=0)
    health_growth_per_wave: float = Field(ge=1)
    damage_growth_per_wave: float = Field(ge=1)


class EnemyArchetype(StrictModel):
    health_multiplier: float = Field(gt=0)
    damage_multiplier: float = Field(ge=0)
    speed_multiplier: float = Field(ge=0)
    reward_multiplier: float = Field(ge=0)
    visual_scale: float = Field(gt=0)
    color: str = Field(pattern=r"^[0-9a-fA-F]{6}$")


class EnemiesConfig(StrictModel):
    base: EnemyBaseConfig
    archetypes: dict[str, EnemyArchetype] = Field(min_length=1)


class BossesConfig(StrictModel):
    archetype: str
    every: int = Field(gt=0)
    additional_enemies: int = Field(ge=0)


class SpawnEntry(StrictModel):
    id: str
    weight: float = Field(gt=0)


class SpawnPool(StrictModel):
    min_wave: int = Field(gt=0)
    entries: list[SpawnEntry] = Field(min_length=1)


class WavesConfig(StrictModel):
    starting_enemy_count: int = Field(gt=0)
    enemy_growth_per_wave: float = Field(ge=1)
    wave_duration_seconds: float = Field(gt=0)
    spawn_pools: list[SpawnPool] = Field(min_length=1)


class EconomyConfig(StrictModel):
    starting_coins: int = Field(ge=0)
    coin_per_kill: int = Field(ge=0)
    boss_coin_reward: int = Field(ge=0)


class UpgradeDefinition(StrictModel):
    id: str = Field(min_length=1)
    display_name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    category: Literal["player", "weapon", "unlock", "utility", "companion", "special"]
    target: str | None = None
    value: float | None = None
    weapon: str | None = None
    max_level: int = Field(ge=1)
    prerequisites: list[str] = Field(default_factory=list)


class UpgradesConfig(StrictModel):
    definitions: list[UpgradeDefinition] = Field(min_length=1)


class GameplayConfig(StrictModel):
    combat_style: Literal["zombie", "space", "ninja"] = "zombie"
    portrait_viewport: bool = True
    enemy_spawn_margin: float = Field(gt=0, default=56)


class CanonicalGameConfig(StrictModel):
    schema_version: Literal["1.0"]
    generator_version: str = Field(min_length=1)
    metadata: MetadataConfig
    theme: ThemeConfig
    terminology: TerminologyConfig
    player: PlayerConfig
    weapons: WeaponsConfig
    enemies: EnemiesConfig
    waves: WavesConfig
    bosses: BossesConfig
    economy: EconomyConfig
    upgrades: UpgradesConfig
    gameplay: GameplayConfig = Field(default_factory=GameplayConfig)

    @model_validator(mode="after")
    def validate_references(self) -> "CanonicalGameConfig":
        archetypes = self.enemies.archetypes
        if self.bosses.archetype not in archetypes:
            raise ValueError("bosses.archetype must reference enemies.archetypes")
        for pool in self.waves.spawn_pools:
            for entry in pool.entries:
                if entry.id not in archetypes:
                    raise ValueError("waves.spawn_pools contains unknown enemy '%s'" % entry.id)
        valid_player_targets = {"damage", "attack_speed", "max_health", "critical_chance", "critical_multiplier"}
        valid_utility_targets = {"heal_percent", "coin_multiplier"}
        valid_special_targets = {"nova_damage", "nova_radius"}
        weapon_targets = {"damage", "cooldown", "projectile_speed", "radius"}
        seen_ids: set[str] = set()
        for upgrade in self.upgrades.definitions:
            if upgrade.id in seen_ids:
                raise ValueError("upgrades.definitions contains duplicate id '%s'" % upgrade.id)
            seen_ids.add(upgrade.id)
            if upgrade.category == "player" and upgrade.target not in valid_player_targets:
                raise ValueError("player upgrade '%s' has invalid target" % upgrade.id)
            if upgrade.category == "utility" and upgrade.target not in valid_utility_targets:
                raise ValueError("utility upgrade '%s' has invalid target" % upgrade.id)
            if upgrade.category == "special" and upgrade.target not in valid_special_targets:
                raise ValueError("special upgrade '%s' has invalid target" % upgrade.id)
            if upgrade.category in {"weapon", "unlock"} and upgrade.weapon not in self.weapons.definitions:
                raise ValueError("weapon upgrade '%s' references an unknown weapon" % upgrade.id)
            if upgrade.category == "weapon" and upgrade.target not in weapon_targets:
                raise ValueError("weapon upgrade '%s' has invalid target" % upgrade.id)
            if upgrade.category not in {"unlock", "companion"}:
                if upgrade.value is None or upgrade.value == 0:
                    raise ValueError("effect upgrades require a nonzero value")
                if upgrade.target != "cooldown" and upgrade.value < 0:
                    raise ValueError("only cooldown upgrades may have negative values")
            if upgrade.category == "weapon":
                kind = self.weapons.definitions[upgrade.weapon].type
                if upgrade.target == "radius" and kind != "area":
                    raise ValueError("radius requires an area weapon")
                if upgrade.target == "projectile_speed" and kind != "projectile":
                    raise ValueError("projectile_speed requires a projectile weapon")
            if upgrade.category in {"unlock", "companion"} and upgrade.max_level != 1:
                raise ValueError("unlock and companion cards must be single-use")
        definitions = {upgrade.id: upgrade for upgrade in self.upgrades.definitions}
        def visit(key, trail):
            if key in trail:
                raise ValueError("cyclic upgrade prerequisites")
            if key not in definitions:
                raise ValueError("unknown upgrade prerequisite")
            for dependency in definitions[key].prerequisites:
                visit(dependency, trail | {key})
        for key in definitions:
            visit(key, set())
        return self


def validate_config(data: dict[str, Any]) -> CanonicalGameConfig:
    return CanonicalGameConfig.model_validate(data)
