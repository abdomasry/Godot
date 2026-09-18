extends SceneTree
# Accelerated engine soak, not a real-time FPS benchmark or physical-device QA.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.start_run()
	game.player.max_health = 10000000
	game.player.current_health = game.player.max_health
	game.player.nova_damage = 45
	game.player.unlock_companion()
	game.player.unlock_weapon("area_pulse")
	var max_enemies := 0
	var max_projectiles := 0
	var elapsed := 0.0
	var frames := 0
	while elapsed < 1200.0:
		await physics_frame
		frames += 1
		elapsed += 1.0 / 60
		game.player.position = Vector2(360, 650) + Vector2(sin(elapsed * 0.4) * 230, cos(elapsed * 0.3) * 380)
		if game.player.can_cast_nova(): game.player.cast_nova()
		if game.state == game.RunState.SELECTING_UPGRADE:
			var offered: Array = game.upgrade_manager.offered
			game._on_upgrade_selected(str(offered[0]) if not offered.is_empty() else "")
		if game.state == game.RunState.PAUSED: game.continue_checkpoint()
		if game.state == game.RunState.GAME_OVER:
			game.start_run()
			game.player.max_health = 10000000
			game.player.current_health = game.player.max_health
		max_enemies = maxi(max_enemies, game.enemies_container.get_child_count())
		max_projectiles = maxi(max_projectiles, get_nodes_in_group("projectiles").size())
	var passed := max_enemies <= 69 and max_projectiles <= 100 # 60 living + 8 corpses + one deferred node.
	if not passed: print("ASSERT_FAIL entity caps")
	print(JSON.stringify({"suite_complete":true, "simulated_seconds":elapsed, "frames":frames, "max_enemy_nodes_including_death_fx":max_enemies, "max_projectiles":max_projectiles, "device_benchmark":false}))
	game.queue_free()
	root.get_node("GameAudio").stop_all()
	await process_frame
	await create_timer(0.1).timeout
	OS.delay_msec(250) # Let the audio thread release stopped playback before process exit.
	quit(0 if passed else 1)
