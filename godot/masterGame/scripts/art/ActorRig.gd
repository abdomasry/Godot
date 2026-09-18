class_name ActorRig
extends Node2D
# Original layered vector rig. It is rendered into real, transparent frame atlases.
var variant := "zombie"
var role := "hero"
var direction := "down"
var animation := "idle"
var frame := 0
var count := 4
const INK := Color("15232a")

func limb(points: PackedVector2Array, width: float, color: Color) -> void:
	draw_polyline(points, INK, width + 4, true)
	draw_polyline(points, color, width, true)
	for point in points:
		draw_circle(point, width * 0.5 + 2, INK)
		draw_circle(point, width * 0.5, color)

func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32): points.append(center + Vector2(cos(index * TAU / 32) * radii.x, sin(index * TAU / 32) * radii.y))
	draw_colored_polygon(points, color)

func _draw() -> void:
	var phase := TAU * float(frame) / count
	var moving := animation == "run"
	var swing := sin(phase) if moving else 0.0
	var lift := absf(cos(phase)) * 2 if moving else sin(phase) * 0.8
	var skin := Color("d6a57e")
	var coat := Color("517667")
	var pants := Color("273c51")
	var accent := Color("f2c56b")
	if variant == "zombie" and role != "hero":
		skin = Color("a7c67b")
		coat = Color("59768b")
		accent = Color("dbea9a")
	elif variant == "space":
		skin = Color("698fa9")
		coat = Color("d6e4df") if role == "hero" else Color("526a93")
		pants = Color("33495f")
		accent = Color("8bedeb") if role == "hero" else Color("ed9465")
	elif variant == "ninja":
		coat = Color("343a5d") if role == "hero" else Color("874947")
		pants = Color("252b49")
		accent = Color("e78375") if role == "hero" else Color("dfbd72")
	if role == "fast": coat = coat.lightened(0.16)
	if role == "tank": coat = coat.darkened(0.24)
	if role == "elite": coat = Color("705880")
	if role == "boss": coat = Color("567342") if variant == "zombie" else Color("655487")
	var torso_width := 19.0 if role not in ["boss", "tank"] else 25.0
	var side := direction == "side"
	var back := direction == "up"
	var progress := float(frame) / maxf(1, count - 1)
	var fall := progress * PI * 0.48 if animation == "death" else 0.0
	var hit := (-0.13 if frame == 0 else 0.1) if animation == "hit" else 0.0
	draw_set_transform(Vector2(0, -lift + (progress * 38 if animation == "death" else 0.0)), fall + hit, Vector2.ONE * (1.0 - progress * 0.18 if animation == "death" else 1.0))
	var hips := [Vector2(-10, 9), Vector2(10, 9)]
	if side: hips = [Vector2(-5, 9), Vector2(5, 9)]
	for index in range(2):
		var gait := swing * (1 if index == 0 else -1)
		var hip: Vector2 = hips[index]
		var foot := Vector2(hip.x + (gait * 20 if side else gait * 2), 54 - (maxf(0, gait) * 12 if side else gait * 9))
		var knee := hip.lerp(foot, 0.5) + Vector2(gait * 6, -absf(gait) * 4)
		limb(PackedVector2Array([hip, knee, foot]), 12 if role != "boss" else 17, pants)
		ellipse(foot + Vector2(4 if side else 0, 2), Vector2(11, 6), INK)
		ellipse(foot + Vector2(4 if side else 0, 0), Vector2(8, 4), Color("695548"))
	var attack := sin(progress * PI) if animation == "attack" else (0.6 + progress * 0.35 if animation == "telegraph" else 0.0)
	# Far arm, then torso, then near arm provide stable overlap and depth.
	var far_hand := Vector2(-torso_width - 6 + swing * 10, 5 - attack * 28)
	limb(PackedVector2Array([Vector2(-torso_width + 4, -27), Vector2(-torso_width - 7, -10), far_hand]), 9, coat.darkened(0.15))
	draw_circle(far_hand, 6, skin)
	var body := PackedVector2Array([Vector2(-torso_width + 3,-36),Vector2(torso_width - 3,-36),Vector2(torso_width,8),Vector2(-torso_width,8)])
	draw_colored_polygon(body, INK)
	var inner := PackedVector2Array([Vector2(-torso_width + 6,-33),Vector2(torso_width - 6,-33),Vector2(torso_width - 3,5),Vector2(-torso_width + 3,5)])
	draw_colored_polygon(inner, coat)
	draw_line(Vector2(-torso_width + 3,0),Vector2(torso_width - 3,0), INK, 6)
	draw_rect(Rect2(-3,-3,6,6),accent)
	if not back:
		draw_line(Vector2(-11,-29),Vector2(-11,-7),accent.darkened(0.25),4)
		draw_rect(Rect2(1,-22,10,8),coat.lightened(0.2))
	var near_hand := Vector2(torso_width + 5 - swing * 12, 8 - attack * 32)
	if side and animation == "attack": near_hand = Vector2(40, -25)
	limb(PackedVector2Array([Vector2(torso_width - 4,-27),Vector2(torso_width + 6,-11),near_hand]),9,coat)
	draw_circle(near_hand,7,INK)
	draw_circle(near_hand,5,skin)
	if role == "hero":
		if variant == "ninja":
			var blade_end := near_hand + Vector2(27,-30).rotated(-attack * 0.8)
			limb(PackedVector2Array([near_hand,blade_end]),4,Color("d9e7e7"))
			draw_line(near_hand + Vector2(-6,-4),near_hand + Vector2(6,4),accent,4)
		else:
			draw_rect(Rect2(near_hand + Vector2(-2,-8),Vector2(24,10)),INK)
			draw_rect(Rect2(near_hand + Vector2(2,-6),Vector2(20,5)),Color("799698"))
			if animation == "attack" and frame == 1:
				draw_colored_polygon(PackedVector2Array([near_hand+Vector2(24,-4),near_hand+Vector2(38,-12),near_hand+Vector2(32,-3),near_hand+Vector2(39,5)]),Color("fff2ae"))
	# Oversized but proportionally fixed head reads at phone scale.
	var head := Vector2(2 if side else 0, -49)
	ellipse(head,Vector2(19,22),INK)
	ellipse(head,Vector2(16,19),skin)
	if variant == "space":
		ellipse(head,Vector2(16,19),coat)
		if not back:
			draw_rect(Rect2(head+Vector2(-12,-6),Vector2(27,14)),INK)
			draw_rect(Rect2(head+Vector2(-9,-3),Vector2(22,7)),accent)
		limb(PackedVector2Array([head+Vector2(-15,0),head+Vector2(-23,-10),head+Vector2(-23,-20)]),3,coat)
	elif variant == "ninja":
		ellipse(head,Vector2(16,19),coat)
		if not back:
			draw_rect(Rect2(head+Vector2(-12,-5),Vector2(26,9)),skin)
			draw_line(head+Vector2(-7,-1),head+Vector2(-3,-1),INK,3)
			draw_line(head+Vector2(7,-1),head+Vector2(11,-1),INK,3)
		draw_line(head+Vector2(-15,-10),head+Vector2(15,-10),accent,4)
		draw_colored_polygon(PackedVector2Array([head+Vector2(-15,-9),head+Vector2(-32,-6+swing*3),head+Vector2(-27,4+swing*3)]),accent)
	else:
		if role == "hero":
			draw_colored_polygon(PackedVector2Array([head+Vector2(-17,-4),head+Vector2(-18,-20),head+Vector2(10,-24),head+Vector2(20,-10),head+Vector2(4,-14)]),Color("65432e"))
		if not back:
			for eye in ([Vector2(10,-3)] if side else [Vector2(-7,-3),Vector2(7,-3)]):
				draw_circle(head+eye,3,INK)
				draw_circle(head+eye+Vector2(1,-1),1,accent)
			draw_line(head+Vector2(0 if side else -6,10),head+Vector2(13 if side else 6,10),INK,3)
			if side: draw_circle(head+Vector2(17,3),4,skin)
	if role == "boss":
		for x in [-12,0,12]: draw_colored_polygon(PackedVector2Array([Vector2(x-4,-66),Vector2(x,-82),Vector2(x+4,-66)]),accent)
