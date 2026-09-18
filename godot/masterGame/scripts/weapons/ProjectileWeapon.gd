class_name ProjectileWeapon
extends WeaponBase

@export var projectile_scene: PackedScene

var projectile_speed: float = 500.0
var projectile_range: float = 500.0

func configure(id: String, definition: Dictionary, owner: Node2D) -> void:
	super.configure(id, definition, owner)
	projectile_speed = float(definition.get("projectile_speed", projectile_speed))
	projectile_range = float(definition.get("range", projectile_range))

func _physics_process(delta: float) -> void:
	if not is_active or owner_actor == null:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		fire_at_nearest_enemy()

func fire_at_nearest_enemy() -> void:
	if get_tree().get_nodes_in_group("projectiles").size() >= 100: return
	var target := find_nearest_enemy()
	if target == null or projectile_scene == null:
		return
	var result := get_damage_result()
	owner_actor.visual_attack = 0.32
	owner_actor.facing_direction = owner_actor.global_position.direction_to(target.global_position)
	if owner_actor.combat_style == "ninja":
		# Aiming into a narrow melee arc is materially different from a ranged shot.
		var aim := owner_actor.global_position.direction_to(target.global_position)
		owner_actor.facing_direction = aim
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var offset: Vector2 = enemy.global_position - owner_actor.global_position
			if not enemy.is_dead and offset.length() < melee_reach() and aim.dot(offset.normalized()) > 0.45:
				var hit := get_damage_result()
				enemy.take_damage(float(hit.damage) * 1.5, bool(hit.critical))
		cooldown_remaining = get_effective_cooldown()
		GameAudio.play_cue("shot")
		return
	var projectile := projectile_scene.instantiate() as Projectile
	projectile.global_position = owner_actor.global_position
	projectile.configure(owner_actor.global_position.direction_to(target.global_position), projectile_speed, projectile_range, float(result["damage"]), bool(result["critical"]))
	get_tree().current_scene.add_child(projectile)
	if owner_actor.combat_style == "space":
		for angle in [-0.18, 0.18]:
			if get_tree().get_nodes_in_group("projectiles").size() >= 100: break
			var extra := projectile_scene.instantiate() as Projectile
			extra.position = owner_actor.global_position
			var hit := get_damage_result()
			extra.configure(owner_actor.global_position.direction_to(target.global_position).rotated(angle), projectile_speed, projectile_range, float(hit.damage) * 0.55, bool(hit.critical))
			get_tree().current_scene.add_child(extra)
	GameAudio.play_cue("shot")
	cooldown_remaining = get_effective_cooldown()

func find_nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := projectile_range * projectile_range
	if owner_actor.combat_style == "ninja": nearest_distance = melee_reach() * melee_reach()
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D or node.get("is_dead"):
			continue
		var enemy := node as Node2D
		var distance := owner_actor.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func melee_reach() -> float:
	return 155.0 * projectile_speed / 500.0

func apply_upgrade(target: String, value: float) -> void:
	super.apply_upgrade(target, value)
	if target == "projectile_speed":
		projectile_speed += value
