extends SceneTree
const STATES := {"idle":4, "run":8, "attack":4, "hit":2, "death":6, "telegraph":6}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 960)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	for variant in ["zombie", "space", "ninja"]:
		var folder: String = "res://assets/rigs/" + variant
		DirAccess.make_dir_recursive_absolute(folder)
		var manifest := {"version":1,"variant":variant,"origin":"Original ActorRig.gd layered vector artwork", "canvas":[128,160],"pivot":[64,130],"roles":{}}
		for role in ["hero", "normal", "fast", "tank", "elite", "boss"]:
			manifest.roles[role] = {}
			for direction in ["down", "up", "side"]:
				var row := 0
				for state in STATES:
					manifest.roles[role][state + "_" + direction] = {"file":role+"_"+direction+".png","fps":10 if state == "run" else 7,"loop":state in ["run","idle"],"rects":[]}
					for frame in range(STATES[state]):
						var rig := ActorRig.new()
						rig.variant = variant
						rig.role = role
						rig.direction = direction
						rig.animation = state
						rig.frame = frame
						rig.count = STATES[state]
						rig.position = Vector2(frame*128+64,row*160+86)
						rig.scale = Vector2.ONE * 0.8
						viewport.add_child(rig)
						manifest.roles[role][state+"_"+direction].rects.append([frame*128,row*160,128,160])
					row += 1
				viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				await process_frame
				await RenderingServer.frame_post_draw
				var result := viewport.get_texture().get_image().save_png(folder+"/"+role+"_"+direction+".png")
				if result != OK:
					print("ASSERT_FAIL bake image")
					quit(1)
					return
				for child in viewport.get_children(): child.free()
		var file := FileAccess.open(folder+"/manifest.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest,"  "))
		file.close()
		print("Baked ",variant)
	viewport.queue_free()
	await process_frame
	quit()
