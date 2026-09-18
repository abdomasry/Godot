class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

@export var max_health: float = 30.0
@export var damage: float = 5.0
@export var movement_speed: float = 80.0
@export var attack_range: float = 60.0
@export var attack_speed: float = 0.5
@export var coin_reward: int = 3

var current_health: float
var player: Node2D
var attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	find_player()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		find_player()
		return

	attack_cooldown = max(attack_cooldown - delta, 0.0)

	var distance := global_position.distance_to(player.global_position)

	if distance > attack_range:
		move_towards_player()
	else:
		attack_player()

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

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

	attack_cooldown = 1.0 / attack_speed

func take_damage(amount: float) -> void:
	current_health -= amount

	if current_health <= 0.0:
		die()

func die() -> void:
	died.emit(self)
	queue_free()