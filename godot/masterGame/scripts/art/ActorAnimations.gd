class_name ActorAnimations
extends RefCounted
static var cache: Dictionary = {}

static func attach(body: AnimatedSprite2D, variant: String, role: String) -> bool:
	var key := variant + ":" + role
	if not cache.has(key):
		var folder := "res://assets/rigs/" + variant + "/"
		if not FileAccess.file_exists(folder + "manifest.json"): return false
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
		if not manifest.roles.has(role): return false
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for animation in manifest.roles[role]:
			var definition: Dictionary = manifest.roles[role][animation]
			frames.add_animation(animation)
			frames.set_animation_speed(animation, float(definition.fps))
			frames.set_animation_loop(animation, bool(definition.loop))
			var texture: Texture2D = load(folder + definition.file)
			for rect in definition.rects:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(rect[0],rect[1],rect[2],rect[3])
				frames.add_frame(animation,atlas)
		cache[key] = frames
	body.sprite_frames = cache[key]
	body.centered = false
	body.offset = Vector2(-64,-130)
	body.scale = Vector2.ONE
	body.play("idle_down")
	return true

static func face(vector: Vector2) -> String:
	if absf(vector.x) > absf(vector.y) * 0.7: return "side"
	return "up" if vector.y < 0 else "down"

static func play(body: AnimatedSprite2D, state: String, facing: Vector2) -> void:
	var direction := face(facing)
	body.flip_h = direction == "side" and facing.x < 0
	var name := state + "_" + direction
	if body.sprite_frames.has_animation(name): body.play(name)
