class_name GameManager
extends Node2D

@export var enemy_scene: PackedScene
enum RunState { RUNNING, SELECTING_UPGRADE, GAME_OVER }

signal coins_changed(total: int)
signal game_over

var coins: int = 0
var state: RunState = RunState.RUNNING

@onready var player: Player = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $CanvasLayer/HUD
@onready var upgrade_panel: UpgradePanel = $CanvasLayer/UpgradePanel

func _ready() -> void:
	if not ConfigManager.load_config():
		push_error("Cannot start the run because the prototype config is invalid.")
		return
	player.configure(ConfigManager.get_player_config())
	coins = ConfigManager.get_int("economy", "starting_coins", 0)
	wave_manager.configure(ConfigManager.get_waves_config())
	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.set_player_health)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	upgrade_panel.upgrade_selected.connect(_on_upgrade_selected)
	hud.set_player_health(player.current_health, player.max_health)
	hud.set_coins(coins)
	coins_changed.emit(coins)
	wave_manager.start_next_wave()

func _on_wave_started(wave: int, enemy_count: int) -> void:
	hud.set_wave(wave)
	hud.set_enemies_remaining(enemy_count)
	for _index in range(enemy_count):
		spawn_enemy(wave)

func spawn_enemy(wave: int) -> void:
	if enemy_scene == null:
		push_error("Enemy scene is not assigned.")
		return
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.global_position = get_spawn_position()
	enemy.configure(ConfigManager.get_enemy_config(), wave, player, ConfigManager.get_int("economy", "coin_per_kill", 0))
	enemy.died.connect(_on_enemy_died)
	enemies_container.add_child(enemy)
func get_spawn_position() -> Vector2:
	var size := get_viewport_rect().size
	var margin := 56.0
	match randi_range(0, 3):
		0: return Vector2(randf_range(0.0, size.x), -margin)
		1: return Vector2(randf_range(0.0, size.x), size.y + margin)
		2: return Vector2(-margin, randf_range(0.0, size.y))
		_: return Vector2(size.x + margin, randf_range(0.0, size.y))

func _on_enemy_died(coin_reward: int) -> void:
	if state != RunState.RUNNING:
		return
	coins += coin_reward
	coins_changed.emit(coins)
	hud.set_coins(coins)
	wave_manager.register_enemy_defeated()
	hud.set_enemies_remaining(wave_manager.enemies_remaining)

func _on_wave_completed(_wave: int) -> void:
	if state != RunState.RUNNING:
		return
	state = RunState.SELECTING_UPGRADE
	await get_tree().create_timer(0.45).timeout
	if state == RunState.SELECTING_UPGRADE:
		upgrade_panel.show_choices(ConfigManager.get_upgrades_config())

func _on_upgrade_selected(upgrade_id: String) -> void:
	if state != RunState.SELECTING_UPGRADE:
		return
	var increase := ConfigManager.get_float("upgrades", upgrade_id, "increase", 0.0)
	match upgrade_id:
		"damage": player.apply_damage_upgrade(increase)
		"attack_speed": player.apply_attack_speed_upgrade(increase)
		"health": player.apply_health_upgrade(increase)
	state = RunState.RUNNING
	wave_manager.start_next_wave()

func _on_player_died() -> void:
	if state == RunState.GAME_OVER:
		return
	state = RunState.GAME_OVER
	hud.show_game_over()
	game_over.emit()
	get_tree().paused = true
