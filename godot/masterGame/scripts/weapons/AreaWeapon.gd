class_name AreaWeapon
extends WeaponBase

var radius: float = 120.0
var visual_time := 0.0

func configure(id: String, definition: Dictionary, owner: Node2D) -> void:
	super.configure(id, definition, owner)
	radius = float(definition.get("radius", radius))

func _physics_process(delta: float) -> void:
	if not is_active or owner_actor == null:
		return
	visual_time = maxf(0, visual_time - delta)
	queue_redraw()
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		pulse()

func pulse() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D or node.get("is_dead"):
			continue
		if owner_actor.global_position.distance_squared_to((node as Node2D).global_position) <= radius * radius and node.has_method("take_damage"):
			var result := get_damage_result()
			node.take_damage(float(result["damage"]), bool(result["critical"]))
	visual_time = 0.22
	queue_redraw()
	cooldown_remaining = get_effective_cooldown()

func apply_upgrade(target: String, value: float) -> void:
	super.apply_upgrade(target, value)
	if target == "radius":
		radius += value

func _draw() -> void:
	if visual_time > 0: draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.35, 0.8, 1.0, visual_time * 3), 5.0)
