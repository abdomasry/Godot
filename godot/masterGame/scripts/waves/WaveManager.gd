class_name WaveManager
extends Node

signal wave_started(wave: int, spawn_plan: Array[Dictionary])
signal wave_completed(wave: int)
signal spawn_requested(wave: int, entry: Dictionary)
signal choice_due
var current_wave := 0
var enemies_remaining := 0
var starting_enemy_count := 4
var enemy_growth_per_wave := 1.1
var boss_every := 5
var boss_additional_enemies := 2
var boss_archetype := "boss"
var spawn_pools: Array = []
var duration := 45.0
var elapsed := 0.0
var spawn_clock := 0.0
var active := false
var boss_defeated := false
var completed := false
var total_stages := 10
var alive_cap := 60
var killed := 0
var retired := 0
var spawned := 0

func configure(stats: Dictionary) -> void:
	starting_enemy_count = int(stats.get("starting_enemy_count", 4))
	enemy_growth_per_wave = float(stats.get("enemy_growth_per_wave", 1.1))
	boss_every = int(stats.get("boss_every", 5))
	boss_additional_enemies = int(stats.get("boss_additional_enemies", 2))
	boss_archetype = str(stats.get("boss_archetype", "boss"))
	spawn_pools = stats.get("spawn_pools", [])
	duration = clampf(float(stats.get("wave_duration_seconds", 45)), 30.0, 60.0)

func reset() -> void:
	current_wave = 0
	enemies_remaining = 0
	elapsed = 0
	active = false
	killed = 0
	retired = 0
	spawned = 0

func start_next_wave() -> void:
	if current_wave >= total_stages: return
	current_wave += 1
	elapsed = 0.0
	spawn_clock = 0.0
	boss_defeated = false
	completed = false
	active = true
	var plan := build_spawn_plan()
	enemies_remaining = plan.size()
	spawned += plan.size()
	wave_started.emit(current_wave, plan)

func tick(delta: float) -> void:
	if not active or completed: return
	# Called by manager after actor physics; player death has priority.
	if boss_defeated:
		completed = true
		active = false
		wave_completed.emit(current_wave)
		return
	elapsed += delta
	if elapsed >= duration:
		elapsed = 0.0
		active = false
		if not is_boss_wave():
			completed = true
			wave_completed.emit(current_wave)
		else: choice_due.emit()
		return
	spawn_clock += delta
	var interval := maxf(0.7, 4.0 / pow(enemy_growth_per_wave, current_wave - 1))
	if spawn_clock >= interval and enemies_remaining < alive_cap:
		spawn_clock = 0.0
		enemies_remaining += 1
		spawned += 1
		spawn_requested.emit(current_wave, {"id":choose_archetype(), "is_boss":false})

func is_boss_wave() -> bool:
	return boss_every > 0 and current_wave > 0 and current_wave % boss_every == 0

func build_spawn_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var count := mini(alive_cap, maxi(1, ceili(starting_enemy_count * pow(enemy_growth_per_wave, current_wave - 1))))
	if is_boss_wave():
		plan.append({"id":boss_archetype, "is_boss":true})
		count = mini(alive_cap - 1, boss_additional_enemies)
	for _index in range(count): plan.append({"id":choose_archetype(), "is_boss":false})
	return plan

func choose_archetype() -> String:
	var selected_pool: Dictionary = {}
	for pool in spawn_pools:
		if pool is Dictionary and int(pool.get("min_wave", 1)) <= current_wave:
			selected_pool = pool
	var entries: Array = selected_pool.get("entries", [])
	var total := 0.0
	for entry in entries: total += float(entry.get("weight", 0))
	var roll := randf() * total
	for entry in entries:
		roll -= float(entry.get("weight", 0))
		if roll <= 0: return str(entry.get("id", "normal"))
	return "normal"

func register_enemy_defeated(boss: bool = false) -> void:
	enemies_remaining = maxi(0, enemies_remaining - 1)
	killed += 1
	if boss: boss_defeated = true

func retire_remaining() -> void:
	retired += enemies_remaining
	enemies_remaining = 0
