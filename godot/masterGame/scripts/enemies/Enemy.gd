class_name Enemy
extends CharacterBody2D


signal died(coin_reward: int)


@export var max_health: float = 30.0
@export var damage: float = 5.0
@export var movement_speed: float = 80.0
@export var attack_range: float = 60.0
@export var attack_speed: float = 0.5
@export var coin_reward: int = 3


var current_health: float
var player: CharacterBody2D
var attack_cooldown: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	add_to_group("enemies")

	current_health = max_health

	if player == null:
		find_player()
	_update_health_bar()

func configure(stats: Dictionary, wave: int, target: CharacterBody2D, reward: int) -> void:
	var health_growth := float(stats.get("health_growth_per_wave", 1.0))
	var damage_growth := float(stats.get("damage_growth_per_wave", 1.0))
	max_health = float(stats.get("base_health", max_health)) * pow(health_growth, wave - 1)
	damage = float(stats.get("base_damage", damage)) * pow(damage_growth, wave - 1)
	movement_speed = float(stats.get("movement_speed", movement_speed))
	coin_reward = reward
	player = target
	current_health = max_health


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		find_player()
		if player == null:
			return

	attack_cooldown = max(attack_cooldown - delta, 0.0)

	var distance := global_position.distance_to(player.global_position)

	if distance > attack_range:
		move_towards_player()
	else:
		attack_player()


func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D


func move_towards_player() -> void:
	if player == null:
		return

	var direction := global_position.direction_to(player.global_position)

	velocity = direction * movement_speed

	move_and_slide()


func attack_player() -> void:
	velocity = Vector2.ZERO

	if attack_cooldown > 0.0:
		return

	if player.has_method("take_damage"):
		player.take_damage(damage)

	attack_cooldown = 1.0 / maxf(attack_speed, 0.01)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	_update_health_bar()
	play_hit_feedback()
	if current_health <= 0.0:
		die()


func die() -> void:
	is_dead = true
	died.emit(coin_reward)
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.14)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_callback(queue_free)

func play_hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property($Body, "modulate", Color.WHITE, 0.04)
	tween.tween_property($Body, "modulate", Color(1.0, 0.2, 0.2), 0.1)

func _update_health_bar() -> void:
	$HealthBar.value = current_health / maxf(max_health, 0.01) * 100.0
