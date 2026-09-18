class_name Companion
extends Node2D

var owner_actor: Node2D
var cooldown := 0.0
var active := true
var attack_range := 320.0
var beam_time := 0.0
var beam_target := Vector2.ZERO

func set_combat_active(value: bool) -> void:
	active = value

func configure(actor: Node2D) -> void:
	owner_actor = actor

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(owner_actor) or owner_actor.is_dead: return
	beam_time = maxf(0.0, beam_time - delta)
	queue_redraw()
	global_position = global_position.lerp(owner_actor.global_position + Vector2(58, -42), minf(1.0, delta * 7.0))
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0: return
	var target: Node2D
	var nearest := attack_range * attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead: continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy
	if target != null and target.has_method("take_damage"):
		target.take_damage(maxf(1.0, float(owner_actor.get("damage")) * 0.45), false)
		beam_target = target.global_position
		beam_time = 0.12
		cooldown = 1.1

func _draw() -> void:
	if beam_time > 0.0: draw_line(Vector2.ZERO, to_local(beam_target), Color.CYAN, 4.0)
	draw_circle(Vector2.ZERO, 18.0, Color("decaff") if is_instance_valid(owner_actor) and owner_actor.combat_style == "ninja" else Color(0.3, 0.9, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.05, 0.14, 0.24))
