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
var critical_chance: float = 0.0
var critical_multiplier: float = 1.0
var coin_reward_multiplier: float = 1.0
var base_damage_stat: float = 1.0
var weapons: Dictionary = {}
var weapon_definitions: Dictionary = {}
var nova_damage := 0.0
var nova_radius := 145.0
var nova_cooldown := 0.0
var movement_active: bool = true
var combat_active: bool = true
var invulnerability := 0.0
var nova_visual := 0.0
var combat_style := "zombie"
var shield := 0.0
var shield_delay := 0.0
var facing_direction := Vector2.DOWN
var hit_tween: Tween
var visual_attack := 0.0
var visual_hit := 0.0
var touch_id: int = -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
const TOUCH_DEAD_ZONE := 18.0
const TOUCH_MAX_RADIUS := 120.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	health_changed.connect(_update_health_bar)

func configure(stats: Dictionary) -> void:
	if hit_tween != null and hit_tween.is_valid(): hit_tween.kill()
	combat_style = str(ConfigManager.get_section("gameplay").get("combat_style", "zombie"))
	ActorAnimations.attach($Body, combat_style, "hero")
	visual_attack = 0.0
	visual_hit = 0.0
	$HealthBar.position.y = -128
	shield = 35.0 if combat_style == "space" else 0.0
	shield_delay = 0.0
	facing_direction = Vector2.DOWN
	set_combat_active(false)
	set_movement_active(false)
	var old_companion := get_node_or_null("Companion")
	if old_companion != null:
		remove_child(old_companion)
		old_companion.queue_free()
	nova_damage = 0.0
	nova_radius = 145.0
	nova_cooldown = 0.0
	nova_visual = 0.0
	invulnerability = 0.0
	attack_cooldown = 0.0
	rotation = 0.0
	scale = Vector2.ONE
	position = get_viewport_rect().size * Vector2(0.5, 0.55)
	$Body.modulate = Color.WHITE
	queue_redraw()
	max_health = float(stats.get("max_health", max_health))
	damage = float(stats.get("damage", damage))
	base_damage_stat = maxf(float(stats.get("reference_damage", 10.0)), 0.01)
	attack_speed = float(stats.get("attack_speed", attack_speed))
	movement_speed = float(stats.get("movement_speed", movement_speed))
	critical_chance = float(stats.get("critical_chance", critical_chance))
	critical_multiplier = float(stats.get("critical_multiplier", critical_multiplier))
	coin_reward_multiplier = 1.0
	max_health *= MetaProgression.health_multiplier()
	damage *= MetaProgression.damage_multiplier()
	is_dead = false
	current_health = max_health
	_update_health_bar(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	if nova_visual > 0.0:
		nova_visual = maxf(0.0, nova_visual - delta)
		queue_redraw()
	if is_dead or not movement_active:
		velocity = Vector2.ZERO
		if is_dead: ActorAnimations.play($Body, "death", facing_direction)
		else: $Body.pause()
		return
	visual_attack = maxf(0, visual_attack - delta)
	visual_hit = maxf(0, visual_hit - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	shield_delay = maxf(0.0, shield_delay - delta)
	if combat_style == "space" and shield_delay <= 0: shield = minf(35.0, shield + delta * 7)
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	input_direction = input_direction.limit_length()
	if touch_id >= 0:
		var touch_offset := touch_position - touch_origin
		if touch_offset.length() >= TOUCH_DEAD_ZONE:
			input_direction = touch_offset.limit_length(TOUCH_MAX_RADIUS) / TOUCH_MAX_RADIUS
	velocity = input_direction * movement_speed
	if velocity.length_squared() > 1.0:
		facing_direction = velocity.normalized()
	ActorAnimations.play($Body, "hit" if visual_hit > 0 else ("attack" if visual_attack > 0 else ("run" if velocity.length_squared() > 1 else "idle")), facing_direction)
	move_and_slide()
	clamp_to_viewport()
	nova_cooldown = maxf(0.0, nova_cooldown - delta)

func _unhandled_input(event: InputEvent) -> void:
	if not movement_active or is_dead: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE:
		cast_nova()
	if event is InputEventScreenTouch:
		if event.pressed and touch_id < 0:
			touch_id = event.index
			touch_origin = event.position
			touch_position = event.position
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_position = event.position

func set_movement_active(active: bool) -> void:
	movement_active = active
	if not active:
		velocity = Vector2.ZERO
		touch_id = -1

func clamp_to_viewport() -> void:
	var rect := get_viewport_rect()
	var margin := 32.0
	global_position = Vector2(
		clampf(global_position.x, margin, rect.size.x - margin),
		clampf(global_position.y, margin, rect.size.y - margin)
	)

func setup_weapons(definitions: Dictionary, starting_weapon_id: String) -> void:
	weapon_definitions = definitions
	clear_weapons()
	unlock_weapon(starting_weapon_id)

func unlock_weapon(weapon_id: String) -> void:
	if has_weapon(weapon_id) or not weapon_definitions.has(weapon_id):
		return
	var definition: Dictionary = weapon_definitions[weapon_id]
	var weapon: WeaponBase
	if definition.get("type", "") == "projectile":
		var projectile_weapon := ProjectileWeapon.new()
		projectile_weapon.projectile_scene = preload("res://scenes/weapons/Projectile.tscn")
		weapon = projectile_weapon
	elif definition.get("type", "") == "area":
		weapon = AreaWeapon.new()
	else:
		push_error("Unsupported weapon type for %s" % weapon_id)
		return
	weapon.name = weapon_id
	add_child(weapon)
	weapon.configure(weapon_id, definition, self)
	weapons[weapon_id] = weapon

func clear_weapons() -> void:
	for weapon in weapons.values():
		if is_instance_valid(weapon):
			weapon.set_combat_active(false)
			remove_child(weapon)
			weapon.queue_free()
	weapons.clear()

func has_weapon(weapon_id: String) -> bool:
	return weapons.has(weapon_id)

func apply_weapon_upgrade(weapon_id: String, target: String, value: float) -> void:
	var weapon := weapons.get(weapon_id) as WeaponBase
	if weapon != null:
		weapon.apply_upgrade(target, value)

func set_combat_active(active: bool) -> void:
	combat_active = active
	var companion := get_node_or_null("Companion")
	if companion != null: companion.set_combat_active(active)
	for weapon in weapons.values():
		if is_instance_valid(weapon):
			weapon.set_combat_active(active)

func roll_weapon_damage(base_damage: float) -> Dictionary:
	var critical := randf() < clampf(critical_chance, 0.0, 1.0)
	var scaled_damage := base_damage * damage / base_damage_stat
	return {"damage": scaled_damage * (critical_multiplier if critical else 1.0), "critical": critical}

func take_damage(amount: float) -> void:
	if is_dead or not combat_active or invulnerability > 0.0:
		return
	if combat_style == "space":
		shield_delay = 7.0
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
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
	if is_dead: return
	is_dead = true
	set_combat_active(false)
	set_movement_active(false)
	died.emit()

func apply_damage_upgrade(amount: float) -> void:
	damage += amount

func apply_attack_speed_upgrade(amount: float) -> void:
	attack_speed = maxf(0.05, attack_speed + amount)

func apply_health_upgrade(amount: float) -> void:
	max_health += amount
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func apply_stat_upgrade(target: String, value: float) -> void:
	match target:
		"damage": apply_damage_upgrade(value)
		"attack_speed": apply_attack_speed_upgrade(value)
		"max_health": apply_health_upgrade(value)
		"critical_chance": critical_chance = minf(1.0, critical_chance + value)
		"critical_multiplier": critical_multiplier += value

func apply_utility_upgrade(target: String, value: float) -> void:
	if target == "heal_percent":
		heal(max_health * value)
	elif target == "coin_multiplier":
		coin_reward_multiplier += value

func apply_special_upgrade(target: String, value: float) -> void:
	if target == "nova_damage": nova_damage += value
	elif target == "nova_radius": nova_radius += value

func can_cast_nova() -> bool:
	return combat_active and nova_damage > 0.0 and nova_cooldown <= 0.0 and not is_dead

func cast_nova() -> bool:
	if not can_cast_nova(): return false
	if combat_style == "ninja":
		var from := global_position
		global_position += facing_direction * 200
		clamp_to_viewport()
		invulnerability = 0.45
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, global_position)
			if not enemy.is_dead and nearest.distance_to(enemy.global_position) <= nova_radius * 0.5:
				enemy.take_damage(nova_damage, false)
		nova_cooldown = 6.0
		nova_visual = 0.2
		GameAudio.play_cue("nova")
		return true
	if combat_style == "space": shield = 35.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and global_position.distance_squared_to(node.global_position) <= nova_radius * nova_radius and node.has_method("take_damage"):
			node.take_damage(nova_damage, true)
	nova_cooldown = 12.0
	GameAudio.play_cue("nova")
	nova_visual = 0.3
	queue_redraw()
	return true

func _draw() -> void:
	if nova_visual > 0.0:
		draw_circle(Vector2.ZERO, nova_radius, Color(0.35, 0.8, 1.0, 0.28))

func unlock_companion() -> void:
	if has_node("Companion"): return
	var companion = preload("res://scripts/weapons/Companion.gd").new()
	companion.name = "Companion"
	add_child(companion)
	companion.configure(self)
	companion.set_combat_active(combat_active)

func play_hit_feedback() -> void:
	visual_hit = 0.2
	GameAudio.play_cue("hit")
	if bool(MetaProgression.data.get("settings", {}).get("reduced_flash", false)): return
	if hit_tween != null and hit_tween.is_valid(): hit_tween.kill()
	hit_tween = create_tween()
	hit_tween.tween_property($Body, "modulate", Color("ffb8a8"), 0.05)
	hit_tween.tween_property($Body, "modulate", Color.WHITE, 0.12)

func _update_health_bar(current: float, maximum: float) -> void:
	$HealthBar.value = current / maximum * 100.0
