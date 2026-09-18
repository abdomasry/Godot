class_name WeaponBase
extends Node2D

var owner_actor: Node2D
var weapon_id: String = ""
var damage: float = 0.0
var cooldown: float = 1.0
var cooldown_remaining: float = 0.0
var is_active: bool = true

func configure(id: String, definition: Dictionary, owner: Node2D) -> void:
	weapon_id = id
	owner_actor = owner
	damage = float(definition.get("damage", damage))
	cooldown = float(definition.get("cooldown", cooldown))

func set_combat_active(active: bool) -> void:
	is_active = active

func apply_upgrade(target: String, value: float) -> void:
	if target == "damage":
		damage += value
	elif target == "cooldown":
		cooldown = maxf(0.08, cooldown + value)

func get_effective_cooldown() -> float:
	var attack_speed := 1.0
	if owner_actor != null:
		attack_speed = float(owner_actor.get("attack_speed"))
	return maxf(0.08, cooldown / maxf(attack_speed, 0.05))

func get_damage_result() -> Dictionary:
	if owner_actor != null and owner_actor.has_method("roll_weapon_damage"):
		return owner_actor.roll_weapon_damage(damage)
	return {"damage": damage, "critical": false}
