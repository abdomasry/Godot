class_name Projectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var remaining_range: float = 500.0
var damage: float = 1.0
var is_critical: bool = false
var has_hit: bool = false

func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	$Body.color = Color(1.0, 0.9, 0.35) if is_critical else Color(0.55, 0.9, 1.0)

func configure(shot_direction: Vector2, shot_speed: float, shot_range: float, shot_damage: float, critical: bool) -> void:
	direction = shot_direction.normalized()
	speed = shot_speed
	remaining_range = shot_range
	damage = shot_damage
	is_critical = critical

func _physics_process(delta: float) -> void:
	var distance := speed * delta
	global_position += direction * distance
	remaining_range -= distance
	if remaining_range <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if has_hit or not body.is_in_group("enemies") or body.get("is_dead"):
		return
	has_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage, is_critical)
	queue_free()
