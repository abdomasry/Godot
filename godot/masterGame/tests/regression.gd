extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("ASSERT_FAIL ", label)
	else:
		print("ASSERT_PASS ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	var meta := root.get_node("MetaProgression")
	check(meta.save_path().contains("profile_"), "variant-scoped save")
	game.player.apply_special_upgrade("nova_damage", 45)
	game.player.unlock_companion()
	game.restart_run()
	check(game.player.nova_damage == 0, "retry clears Nova")
	check(not game.player.has_node("Companion"), "retry clears companion")
	var definition := {"id":"null_test", "category":"player", "target":"damage", "value":3, "weapon":null, "max_level":3}
	check(game.upgrade_manager.is_eligible(definition), "nullable weapon does not exclude player upgrade")
	game._on_player_died()
	var before: int = root.get_node("MetaProgression").gems
	game._on_chest_requested()
	game._on_chest_requested()
	check(root.get_node("MetaProgression").gems == before, "unfunded chest never grants free gems")
	for attempt in range(20):
		game.start_run()
		game.player.unlock_companion()
		game.player.unlock_companion()
		check(game.player.get_node("Companion") != null, "named companion %s" % attempt)
		game.player.nova_damage = 45
		game.start_run()
		check(game.player.nova_damage == 0 and not game.player.has_node("Companion"), "clean retry %s" % attempt)
	game.player.critical_chance = 0
	game.player.damage = 10
	var low: float = game.player.roll_weapon_damage(8).damage
	game.player.damage = 20
	check(game.player.roll_weapon_damage(8).damage == low * 2, "preset damage is not cancelled by denominator")
	game.player.nova_damage = 45
	game.player.unlock_companion()
	game.pause_run()
	check(not game.player.can_cast_nova() and not game.player.get_node("Companion").active, "pause stops Nova and companion")
	var frozen: float = game.wave_manager.elapsed
	game._process(10)
	check(game.wave_manager.elapsed == frozen, "pause stops director clock")
	game.resume_run()
	game.wave_manager.register_enemy_defeated()
	check(game.wave_manager.current_wave == 1 and game.state == game.RunState.RUNNING, "last kill cannot skip timed stage")
	game.wave_manager.tick(45)
	check(game.state == game.RunState.SELECTING_UPGRADE, "timed stage opens choice")
	check(not game.upgrade_manager.apply_upgrade("not_offered"), "unoffered card rejected")
	var choices: Array = game.upgrade_manager.get_choices()
	check(not choices.is_empty(), "canonical card pool nonempty")
	if not choices.is_empty():
		var id: String = choices[0].id
		check(game.upgrade_manager.apply_upgrade(id), "offered card accepted")
		check(not game.upgrade_manager.apply_upgrade(id), "duplicate selection rejected")
	check(not game.upgrade_manager.is_eligible({"id":"radius", "category":"special", "target":"nova_radius", "max_level":3}) or game.player.nova_damage > 0, "Nova radius prerequisite")
	game.start_run()
	game.wave_manager.current_wave = 4
	game.clear_combat_nodes()
	game.wave_manager.start_next_wave()
	game.wave_manager.tick(45)
	check(game.wave_manager.current_wave == 5 and game.state == game.RunState.SELECTING_UPGRADE and not game.advance_after_choice, "boss timer offers without advancing")
	game.continue_checkpoint()
	game.wave_manager.register_enemy_defeated(true)
	game.wave_manager.tick(0.1)
	check(game.advance_after_choice and game.pending_gems == 5, "boss completion has one Gem payout")
	game.start_run()
	var old_token: int = game.generation - 1
	game._on_enemy_died(100, false, old_token)
	check(game.coins == 0, "stale run callback ignored")
	check(meta.settle_run("qa-once", 100, 20), "atomic settlement accepted")
	check(not meta.settle_run("qa-once", 100, 20), "duplicate settlement rejected")
	var bank: int = meta.banked_coins
	check(meta.buy_chest() and meta.banked_coins == bank - 100, "chest spends Coins")
	check(not meta.buy_chest(), "cannot buy unfunded chest")
	var saved: int = meta.gems
	meta.test_fail_save = true
	check(not meta.add_gems(20) and meta.gems == saved, "failed save rolls back wallet")
	meta.test_fail_save = false
	meta.load_progress()
	check(meta.gems == saved, "wallet survives reload")
	var ads := root.get_node("RewardedAds")
	ads.debug_mock = true
	ads.set_context("qa", 1)
	var request: String = ads.request_reward("gems")
	check(ads.finish(request, "earned"), "mock earned accepted")
	check(not ads.finish(request, "earned") and meta.gems == saved + 20, "duplicate earned callback cannot pay twice")
	request = ads.request_reward("gems")
	check(not ads.finish(request, "cancelled") and meta.gems == saved + 20, "dismissal pays nothing")
	request = ads.request_reward("gems")
	ads.set_context("next", 2)
	check(not ads.finish(request, "earned"), "stale ad callback rejected")
	meta.select_profile("qa_other_variant")
	check(meta.gems == 0 and meta.banked_coins == 0, "variants have independent wallets")
	check(meta.checkpoint_run("interrupted", 12, 3), "persist interrupted run ledger")
	meta.load_progress()
	check(meta.recover_interrupted_run() and meta.banked_coins == 12 and meta.gems == 3, "recover committed checkpoint")
	check(meta.recover_interrupted_run() and meta.gems == 3, "recovery cannot duplicate settlement")
	var bad: Dictionary = meta.data.duplicate(true)
	bad.damage_level = 1000
	check(not meta.commit(bad), "enormous permanent levels rejected")
	bad = meta.data.duplicate(true)
	bad.pending_run = {"id":"invalid", "coins":0.5, "gems":3}
	check(not meta.commit(bad), "fractional interrupted ledger rejected")
	check(meta.add_gems(7), "backup fixture first commit")
	var backup_gems: int = meta.gems
	check(meta.add_gems(9), "backup fixture second commit")
	var corrupt := FileAccess.open(meta.save_path(), FileAccess.WRITE)
	corrupt.store_string("{broken save")
	corrupt.close()
	meta.load_progress()
	check(meta.gems == backup_gems, "corrupt primary recovers validated backup")
	check(meta.checkpoint_run("recover-failure", 10, 2), "recovery failure fixture")
	meta.test_fail_save = true
	check(not meta.recover_interrupted_run() and not meta.data.pending_run.is_empty(), "failed recovery preserves pending ledger")
	meta.test_fail_save = false
	check(meta.recover_interrupted_run(), "pending ledger recovery can retry")
	game.start_run()
	game.offer_upgrade(false)
	var stale_offer: int = game.upgrade_manager.offer_id
	game.offer_upgrade(false)
	var offered_id: String = game.upgrade_manager.offered[0]
	game._on_upgrade_selected(offered_id, stale_offer)
	check(game.state == game.RunState.SELECTING_UPGRADE and game.upgrade_manager.levels.is_empty(), "stale UI offer cannot select matching new card")
	game.start_run()
	game.clear_combat_nodes()
	game.wave_manager.current_wave = 9
	game.wave_manager.start_next_wave()
	game.wave_manager.register_enemy_defeated(true)
	game.wave_manager.tick(0.1)
	check(game.victory and game.state == game.RunState.GAME_OVER and game.settled, "boss 10 settles victory")
	check(game.pending_gems == 15, "boss plus chapter Gems paid once")
	var victory_bank: int = meta.gems
	game.finish_run()
	check(meta.gems == victory_bank, "repeated results cannot settle again")
	game.start_run()
	game.player.die()
	game.wave_manager.boss_defeated = true
	game._process(45)
	check(game.state == game.RunState.REVIVE_OFFER and game.pending_gems == 0, "death beats timer and boss transition")
	game.start_run()
	for id in ["player_damage", "player_attack_speed", "player_health", "crit_chance", "unlock_area_pulse", "unlock_companion", "unlock_nova"]:
		game.upgrade_manager.get_choices(100)
		check(game.upgrade_manager.apply_upgrade(id), "upgrade family applies: " + id)
	check(game.player.has_weapon("area_pulse") and game.player.has_node("Companion") and game.player.nova_damage > 0, "weapon companion and special have live effects")
	game.player.combat_style = "space"
	game.player.shield = 35
	var hp: float = game.player.current_health
	game.player.take_damage(10)
	check(game.player.shield == 25 and game.player.current_health == hp, "space shield absorbs hit")
	game.player.combat_style = "ninja"
	game.player.facing_direction = Vector2.RIGHT
	game.player.position = Vector2(200, 500)
	game.player.nova_cooldown = 0
	check(game.player.cast_nova() and game.player.position.x > 300 and game.player.invulnerability > 0, "ninja special dashes with brief protection")
	root.get_node("GameAudio").stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	OS.delay_msec(250)
	print(JSON.stringify({"suite_complete":true, "checks":checks, "failures":failures}))
	quit(1 if failures else 0)
