class_name Player
extends CharacterBody2D

signal health_changed(current_health: float, max_health: float)
signal died

@export var max_health: float = 100.0
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var attack_range: float = 300.0
@export var movement_speed: float = 200.0

var current_health: float
var attack_cooldown: float = 0.0
var is_dead: bool = false

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	health_changed.connect(_update_health_bar)

func configure(stats: Dictionary) -> void:
	max_health = float(stats.get("max_health", max_health))
	damage = float(stats.get("damage", damage))
	attack_speed = float(stats.get("attack_speed", attack_speed))
	movement_speed = float(stats.get("movement_speed", movement_speed))
	current_health = max_health
	_update_health_bar(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	auto_attack()

func auto_attack() -> void:
	if attack_cooldown > 0.0:
		return

	var target := get_nearest_enemy()

	if target == null:
		return

	var distance := global_position.distance_to(target.global_position)

	if distance > attack_range:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)

	attack_cooldown = 1.0 / maxf(attack_speed, 0.01)

func get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")

	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for node in enemies:
		if not node is Node2D:
			continue
		var enemy := node as Node2D
		var distance := global_position.distance_to(enemy.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	current_health = maxf(current_health, 0.0)

	health_changed.emit(current_health, max_health)
	play_hit_feedback()

	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	current_health += amount
	current_health = minf(current_health, max_health)

	health_changed.emit(current_health, max_health)

func die() -> void:
	is_dead = true
	died.emit()

func apply_damage_upgrade(amount: float) -> void:
	damage += amount

func apply_attack_speed_upgrade(amount: float) -> void:
	attack_speed = maxf(0.05, attack_speed + amount)

func apply_health_upgrade(amount: float) -> void:
	max_health += amount
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func play_hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property($Body, "modulate", Color.WHITE, 0.05)
	tween.tween_property($Body, "modulate", Color(0.1, 0.6, 1.0), 0.12)

func _update_health_bar(current: float, maximum: float) -> void:
	$HealthBar.value = current / maximum * 100.0
