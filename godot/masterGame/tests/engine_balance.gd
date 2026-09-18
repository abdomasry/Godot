extends SceneTree
# Uses real actors/upgrades/director. Orbit movement is a test policy, not human play.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var runs: Array[Dictionary] = []
	for seed_value in [1, 7, 42, 12345]:
		seed(seed_value)
		game.start_run()
		var elapsed := 0.0
		while elapsed < 900 and game.state not in [game.RunState.REVIVE_OFFER, game.RunState.GAME_OVER]:
			await physics_frame
			elapsed += 1.0 / 60
			if game.state == game.RunState.RUNNING:
				game.player.position = Vector2(360, 650) + Vector2(sin(elapsed * 0.5) * 220, cos(elapsed * 0.4) * 360)
				if game.player.can_cast_nova(): game.player.cast_nova()
			elif game.state == game.RunState.SELECTING_UPGRADE:
				var offer: Array = game.upgrade_manager.offered
				game._on_upgrade_selected(str(offer.pick_random()) if not offer.is_empty() else "")
			elif game.state == game.RunState.PAUSED: game.continue_checkpoint()
		var outcome := "victory" if game.victory else ("death" if game.player.is_dead else "timeout")
		runs.append({"seed":seed_value, "outcome":outcome, "stage":game.wave_manager.current_wave, "seconds":elapsed,
			"coins":game.earned_coins, "gems":game.pending_gems, "upgrades":game.upgrade_manager.levels.duplicate(), "hp":game.player.current_health})
	print("BALANCE_JSON " + JSON.stringify({"runs":runs, "movement_policy":"scripted orbit, not human play", "physics":"Godot real actors", "release_approved":false}))
	game.queue_free()
	root.get_node("GameAudio").stop_all()
	await process_frame
	await create_timer(0.1).timeout
	OS.delay_msec(250)
	print(JSON.stringify({"suite_complete":true}))
	quit()
