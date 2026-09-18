extends Node

const LIMIT := 1000000000
var profile := "default"
var data: Dictionary = {}
var last_error := ""
var test_fail_save := false
var gems: int:
	get: return int(data.get("gems", 0))
var banked_coins: int:
	get: return int(data.get("coins", 0))
var permanent_damage_level: int:
	get: return int(data.get("damage_level", 0))
var permanent_health_level: int:
	get: return int(data.get("health_level", 0))

func _ready() -> void:
	select_profile("default")

func save_path() -> String:
	return "user://profile_%s.json" % profile

func select_profile(id: String) -> void:
	profile = id.validate_filename().replace(".", "_")
	load_progress()

func defaults() -> Dictionary:
	return {"schema":2, "profile":profile, "revision":0, "gems":0, "coins":0,
		"damage_level":0, "health_level":0, "receipts":{}, "daily":{}, "settings":{}, "pending_run":{}}

func valid(candidate: Variant) -> bool:
	if not candidate is Dictionary or candidate.get("schema") != 2 or candidate.get("profile") != profile: return false
	for key in ["gems", "coins", "revision", "damage_level", "health_level"]:
		var value: Variant = candidate.get(key)
		if not (value is int or value is float): return false
		if not is_finite(float(value)) or value != floor(value) or value < 0 or value > LIMIT: return false
	if candidate.damage_level > 10 or candidate.health_level > 10: return false
	for key in ["receipts", "daily", "settings"]:
		if not candidate.get(key) is Dictionary: return false
	var pending: Variant = candidate.get("pending_run", {})
	if not pending is Dictionary: return false
	if not pending.is_empty():
		if not pending.get("id") is String or pending.id.is_empty(): return false
		for key in ["coins", "gems"]:
			var value: Variant = pending.get(key)
			if not (value is int or value is float): return false
			if not is_finite(float(value)) or value != floor(value) or value < 0 or value > LIMIT: return false
	return true

func load_progress() -> void:
	data = defaults()
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(save_path() + suffix):
			var parsed: Variant = read_json(save_path() + suffix)
			if valid(parsed):
				data = parsed
				return
	if profile == "zombieSurvivor" and not FileAccess.file_exists(save_path()) and FileAccess.file_exists("user://meta_progression.save"):
		var legacy: Variant = read_json("user://meta_progression.save")
		if legacy is Dictionary:
			var migrated := defaults()
			migrated.gems = clampi(int(legacy.get("gems", 0)), 0, LIMIT)
			migrated.damage_level = clampi(int(legacy.get("permanent_damage_level", 0)), 0, 10)
			migrated.health_level = clampi(int(legacy.get("permanent_health_level", 0)), 0, 10)
			commit(migrated)

func read_json(path: String) -> Variant:
	# Malformed user data is an expected recovery case, not an engine error.
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func commit(candidate: Dictionary) -> bool:
	last_error = ""
	if not valid(candidate) or (OS.is_debug_build() and test_fail_save):
		last_error = "Save validation or test-injected write failure"
		return false
	candidate = candidate.duplicate(true)
	candidate.revision = int(data.get("revision", 0)) + 1
	var temporary := save_path() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write progression"
		return false
	file.store_string(JSON.stringify(candidate))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Cannot flush progression to storage"
		return false
	if FileAccess.file_exists(save_path()):
		var previous: Variant = read_json(save_path())
		if valid(previous) and DirAccess.copy_absolute(save_path(), save_path() + ".bak") != OK:
			last_error = "Cannot back up progression"
			return false
	if DirAccess.rename_absolute(temporary, save_path()) != OK:
		last_error = "Cannot atomically replace progression"
		return false
	data = candidate
	return true

func upgrade_cost(level: int) -> int: return 20 + level * 15

func buy_level(key: String) -> bool:
	if key not in ["damage_level", "health_level"]: return false
	var level := int(data.get(key, 0))
	var cost := upgrade_cost(level)
	if level >= 10 or gems < cost: return false
	var next := data.duplicate(true)
	next.gems -= cost
	next[key] += 1
	return commit(next)

func buy_permanent_damage() -> bool: return buy_level("damage_level")
func buy_permanent_health() -> bool: return buy_level("health_level")
func damage_multiplier() -> float: return 1.0 + permanent_damage_level * 0.05
func health_multiplier() -> float: return 1.0 + permanent_health_level * 0.05

func add_gems(amount: int) -> bool:
	if amount < 0: return false
	var next := data.duplicate(true)
	next.gems = mini(LIMIT, gems + amount)
	return commit(next)

func settle_run(run_id: String, coins: int, earned_gems: int) -> bool:
	var receipt := "settlement:" + run_id
	if data.receipts.has(receipt) or coins < 0 or earned_gems < 0: return false
	var next := data.duplicate(true)
	next.coins = mini(LIMIT, banked_coins + coins)
	next.gems = mini(LIMIT, gems + earned_gems)
	next.receipts[receipt] = true
	next.pending_run = {}
	return commit(next)

func checkpoint_run(id: String, coins: int, earned_gems: int) -> bool:
	if id.is_empty() or coins < 0 or earned_gems < 0: return false
	var next := data.duplicate(true)
	next.pending_run = {"id":id, "coins":mini(coins, LIMIT), "gems":mini(earned_gems, LIMIT)}
	return commit(next)

func recover_interrupted_run() -> bool:
	var pending: Variant = data.get("pending_run", {})
	if not pending is Dictionary or pending.is_empty(): return true
	if not pending.get("id") is String: return false
	for key in ["coins", "gems"]:
		if not (pending.get(key) is int or pending.get(key) is float): return false
		if pending[key] < 0 or pending[key] > LIMIT: return false
	return settle_run(pending.id, int(pending.coins), int(pending.gems))

func grant_once(receipt: String, coins: int, earned_gems: int, daily_key: String = "", daily_cap: int = 3) -> bool:
	if receipt.is_empty() or data.receipts.has(receipt) or coins < 0 or earned_gems < 0: return false
	var next := data.duplicate(true)
	if not daily_key.is_empty():
		var dated := Time.get_date_string_from_system(true) + ":" + daily_key
		if int(next.daily.get(dated, 0)) >= daily_cap: return false
		next.daily[dated] = int(next.daily.get(dated, 0)) + 1
	next.receipts[receipt] = true
	next.coins = mini(LIMIT, banked_coins + coins)
	next.gems = mini(LIMIT, gems + earned_gems)
	return commit(next)

func buy_chest() -> bool:
	if banked_coins < 100: return false
	var next := data.duplicate(true)
	next.coins -= 100
	next.gems = mini(LIMIT, gems + 5)
	return commit(next)

func set_setting(key: String, value: Variant) -> bool:
	var next := data.duplicate(true)
	next.settings[key] = value
	return commit(next)
