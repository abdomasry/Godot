class_name UpgradeManager
extends Node

signal upgrade_applied(definition: Dictionary, level: int)

var definitions: Array[Dictionary] = []
var levels: Dictionary = {}
var player: Player
var offered: Array[String] = []
var offer_id := 0

func configure(upgrade_config: Dictionary, player_actor: Player) -> void:
	player = player_actor
	definitions.clear()
	for entry in upgrade_config.get("definitions", []):
		if entry is Dictionary:
			definitions.append(entry)

func reset() -> void:
	levels.clear()
	offered.clear()
	offer_id += 1

func get_choices(count: int = 3) -> Array[Dictionary]:
	offered.clear()
	offer_id += 1
	var eligible: Array[Dictionary] = []
	for definition in definitions:
		if is_eligible(definition):
			eligible.append(definition)
	eligible.shuffle()
	var choices: Array[Dictionary] = []
	for index in range(mini(count, eligible.size())):
		choices.append(eligible[index])
		offered.append(str(eligible[index]["id"]))
	return choices

func is_eligible(definition: Dictionary) -> bool:
	var id := str(definition.get("id", ""))
	if id.is_empty() or int(levels.get(id, 0)) >= int(definition.get("max_level", 999)):
		return false
	var weapon_id := str(definition.get("weapon") if definition.get("weapon") != null else "")
	var target := str(definition.get("target") if definition.get("target") != null else "")
	if target == "nova_radius" and player.nova_damage <= 0.0: return false
	if target == "critical_chance" and player.critical_chance >= 1.0: return false
	if target == "heal_percent" and player.current_health >= player.max_health: return false
	if definition.get("category") == "companion" and player.has_node("Companion"): return false
	for prerequisite in definition.get("prerequisites", []):
		if int(levels.get(prerequisite, 0)) == 0: return false
	if definition.get("category", "") == "unlock":
		return not player.has_weapon(weapon_id)
	if not weapon_id.is_empty() and not player.has_weapon(weapon_id):
		return false
	if definition.get("category") == "weapon" and target == "cooldown" and player.has_weapon(weapon_id):
		if player.weapons[weapon_id].get_effective_cooldown() <= 0.08: return false
	return true

func has_eligible() -> bool:
	for definition in definitions:
		if is_eligible(definition): return true
	return false

func apply_upgrade(id: String, expected_offer: int = -1) -> bool:
	if expected_offer >= 0 and expected_offer != offer_id: return false
	if not offered.has(id): return false
	for definition in definitions:
		if definition.get("id", "") != id or not is_eligible(definition):
			continue
		apply_definition(definition)
		levels[id] = int(levels.get(id, 0)) + 1
		offered.clear()
		upgrade_applied.emit(definition, levels[id])
		GameAudio.play_cue("upgrade")
		return true
	return false

func apply_definition(definition: Dictionary) -> void:
	var category := str(definition.get("category", ""))
	var target := str(definition.get("target") if definition.get("target") != null else "")
	var value := float(definition.get("value") if definition.get("value") != null else 0.0)
	if category == "player":
		player.apply_stat_upgrade(target, value)
	elif category == "weapon":
		player.apply_weapon_upgrade(str(definition.get("weapon", "")), target, value)
	elif category == "unlock":
		player.unlock_weapon(str(definition.get("weapon", "")))
	elif category == "utility":
		player.apply_utility_upgrade(target, value)
	elif category == "special":
		player.apply_special_upgrade(target, value)
	elif category == "companion":
		player.unlock_companion()
