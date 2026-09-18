extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("QA_EVIDENCE_DIR")
	if directory.is_empty():
		print("ASSERT_FAIL render test requires isolated QA runner")
		quit(1)
		return
	var result := root.get_texture().get_image().save_png(directory.path_join(file + ".png"))
	if result != OK: print("ASSERT_FAIL screenshot save failed")
func run() -> void:
	var game = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await capture("menu")
	game.start_run()
	for frame in range(480): await process_frame
	await capture("gameplay")
	game.offer_upgrade(false)
	await capture("upgrades")
	game.show_shop(game.show_menu)
	await capture("shop")
	game.queue_free()
	root.get_node("GameAudio").stop_all()
	await process_frame
	OS.delay_msec(250)
	print(JSON.stringify({"suite_complete":true}))
	quit()
