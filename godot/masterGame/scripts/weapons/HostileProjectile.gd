extends Node2D
var direction := Vector2.RIGHT
var damage := 5.0
var target: Node2D
var remaining := 5.0
func _ready() -> void: add_to_group("projectiles")
func _physics_process(delta: float) -> void:
	remaining -= delta
	position += direction * 220 * delta
	if remaining <= 0:
		queue_free()
		return
	if is_instance_valid(target) and not target.is_dead and position.distance_squared_to(target.position) < 900:
		target.take_damage(damage)
		queue_free()
func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color("ec7449"))
	draw_circle(Vector2.ZERO, 5, Color("ffe3b0"))
