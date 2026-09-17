extends Node

const DEFAULT_CONFIG_PATH := "res://configs/prototype.json"
const REQUIRED_SECTIONS := ["player", "enemy", "waves", "economy", "upgrades"]

var config: Dictionary = {}
var last_error: String = ""

func load_config(path: String = DEFAULT_CONFIG_PATH) -> bool:
	config.clear()
	last_error = ""
	if not FileAccess.file_exists(path):
		return fail("Game configuration is missing: %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return fail("Game configuration must contain a JSON object: %s" % path)
	for section in REQUIRED_SECTIONS:
		if not parsed.has(section) or not parsed[section] is Dictionary:
			return fail("Game configuration is missing required object '%s'." % section)
	config = parsed
	return true

func fail(message: String) -> bool:
	last_error = message
	push_error(message)
	return false

func get_section(section: String) -> Dictionary:
	var section_value: Variant = config.get(section, {})
	if section_value is Dictionary:
		return section_value
	return {}

func get_player_config() -> Dictionary:
	return get_section("player")

func get_enemy_config() -> Dictionary:
	return get_section("enemy")

func get_waves_config() -> Dictionary:
	return get_section("waves")

func get_upgrades_config() -> Dictionary:
	return get_section("upgrades")

func get_int(section: String, key: String, fallback: int = 0) -> int:
	return int(get_section(section).get(key, fallback))

func get_float(section: String, key: String, nested_key: String = "", fallback: float = 0.0) -> float:
	var value: Variant = get_section(section).get(key, fallback)
	if not nested_key.is_empty() and value is Dictionary:
		value = value.get(nested_key, fallback)
	return float(value)
