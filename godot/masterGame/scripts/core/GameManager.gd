class_name GameManager
extends Node2D

@export var enemy_scene: PackedScene
enum RunState { BOOT, MAIN_MENU, RUNNING, PAUSED, SELECTING_UPGRADE, REVIVE_OFFER, GAME_OVER, META_SHOP, AD_PENDING }
signal coins_changed(total: int)
signal game_over
var coins := 0
var earned_coins := 0
var pending_gems := 0
var generation := 0
var run_id := ""
var checkpoint := 0
var run_purchases := 0
var purchased_checkpoint := -1
var revived := false
var victory := false
var settled := false
var advance_after_choice := false
var bonus_offer := false
var state: RunState = RunState.BOOT
var screen: ScreenPanel
var pause_button: Button
var timer_label: Label
var shield_label: Label
var ad_origin: RunState
var ad_request := ""
var ad_placement := ""
var return_to: Callable
var journal_clock := 0.0
var recovery_pending := false

@onready var player: Player = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var wave_manager: WaveManager = $WaveManager
@onready var upgrade_manager: UpgradeManager = $UpgradeManager
@onready var hud: HUD = $CanvasLayer/HUD
@onready var upgrade_panel: UpgradePanel = $CanvasLayer/UpgradePanel
@onready var game_over_panel: GameOverPanel = $CanvasLayer/GameOverPanel

func _ready() -> void:
	if not ConfigManager.load_config(): return
	MetaProgression.select_profile(str(ConfigManager.config.get("id", "zombieSurvivor")))
	recovery_pending = not MetaProgression.recover_interrupted_run()
	var style := str(ConfigManager.get_section("gameplay").get("combat_style", "zombie"))
	var arena := "res://assets/arenas/%s.png" % style
	if ResourceLoader.exists(arena): $Background.texture = load(arena)
	get_viewport().size_changed.connect(resize_arena)
	resize_arena()
	AudioServer.set_bus_mute(0, bool(MetaProgression.data.settings.get("muted", false)))
	GameAudio.set_music_enabled(bool(MetaProgression.data.settings.get("music", true)))
	wave_manager.configure(ConfigManager.get_waves_config())
	upgrade_manager.configure(ConfigManager.get_upgrades_config(), player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.set_player_health)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.spawn_requested.connect(spawn_enemy)
	wave_manager.choice_due.connect(func(): offer_upgrade(false))
	upgrade_panel.upgrade_selected.connect(_on_upgrade_selected)
	hud.special_pressed.connect(_on_special_pressed)
	game_over_panel.restart_requested.connect(restart_run)
	game_over_panel.chest_requested.connect(_on_chest_requested)
	screen = ScreenPanel.new()
	$CanvasLayer.add_child(screen)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.position = Vector2(500, 40)
	pause_button.size = Vector2(180, 96)
	pause_button.add_theme_font_size_override("font_size", 28)
	hud.add_child(pause_button)
	pause_button.pressed.connect(pause_run)
	timer_label = Label.new()
	timer_label.position = Vector2(380, 148)
	timer_label.add_theme_font_size_override("font_size", 26)
	hud.add_child(timer_label)
	shield_label = Label.new()
	shield_label.add_theme_font_size_override("font_size", 26)
	hud.get_node("Margin/Rows").add_child(shield_label)
	shield_label.hide()
	RewardedAds.reward_granted.connect(_reward_earned)
	RewardedAds.request_finished.connect(_reward_finished)
	show_menu()

func resize_arena() -> void:
	$Background.size = get_viewport_rect().size

func _process(delta: float) -> void:
	if state != RunState.RUNNING: return
	if player.is_dead:
		_on_player_died()
		return
	wave_manager.tick(delta)
	journal_clock += delta
	if journal_clock >= 5.0:
		journal_clock = 0.0
		MetaProgression.checkpoint_run(run_id, coins, pending_gems)
	hud.set_enemies_remaining(wave_manager.enemies_remaining)
	timer_label.text = "Upgrade in %ds" % ceili(wave_manager.duration - wave_manager.elapsed)
	hud.special_button.disabled = not player.can_cast_nova()
	var ability := "DASH" if player.combat_style == "ninja" else ("EMP" if player.combat_style == "space" else "NOVA")
	hud.special_button.text = ability + (": LOCKED" if player.nova_damage <= 0 else (": READY" if player.can_cast_nova() else ": %ds" % ceili(player.nova_cooldown)))
	if player.combat_style == "space":
		shield_label.text = "SHIELD  %d / 35" % int(player.shield)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == RunState.RUNNING: pause_run()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state == RunState.RUNNING: pause_run()
		elif state == RunState.PAUSED: resume_run()
		get_viewport().set_input_as_handled()

func set_state(next: RunState) -> void:
	state = next
	var active := state == RunState.RUNNING
	player.set_combat_active(active)
	player.set_movement_active(active)
	wave_manager.active = active
	for enemy in enemies_container.get_children(): enemy.set_combat_active(active)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func action(label: String, callback: Callable, disabled: bool = false) -> Dictionary:
	return {"label":label, "callback":callback, "disabled":disabled}

func show_menu() -> void:
	set_state(RunState.MAIN_MENU)
	hud.hide()
	upgrade_panel.hide()
	game_over_panel.hide()
	if recovery_pending:
		screen.present("SAVE NEEDS ATTENTION", "Your previous expedition is safe in its checkpoint. Retry recovery before starting another run.", [action("RETRY RECOVERY", func(): recovery_pending = not MetaProgression.recover_interrupted_run(); show_menu())])
		return
	screen.present(str(ConfigManager.config.get("name", "Survivor")), "SURVIVE • ADAPT • RETURN\n10 stages. A new choice every 45 seconds.\nBank %d Coins • %d Gems" % [MetaProgression.banked_coins, MetaProgression.gems], [
		action("START EXPEDITION", start_run), action("PERMANENT UPGRADES", func(): show_shop(show_menu)),
		action("HOW TO PLAY", show_tutorial), action("SETTINGS", func(): show_settings(show_menu))])

func start_run() -> void:
	if recovery_pending: return
	generation += 1
	run_id = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), generation]
	checkpoint = 0
	coins = ConfigManager.get_int("economy", "starting_coins", 0)
	earned_coins = 0
	pending_gems = 0
	run_purchases = 0
	purchased_checkpoint = -1
	revived = false
	victory = false
	settled = false
	bonus_offer = false
	journal_clock = 0.0
	clear_combat_nodes()
	wave_manager.reset()
	upgrade_manager.reset()
	player.configure(ConfigManager.get_player_config())
	shield_label.visible = player.combat_style == "space"
	player.setup_weapons(ConfigManager.get_weapon_definitions(), ConfigManager.get_starting_weapon_id())
	RewardedAds.set_context(run_id, checkpoint)
	MetaProgression.checkpoint_run(run_id, coins, pending_gems)
	screen.hide()
	upgrade_panel.hide()
	game_over_panel.hide()
	hud.show()
	hud.set_currency_name(str(ConfigManager.get_section("terminology").get("soft_currency_name", "Coins")))
	update_wallet()
	hud.set_move_hint_visible(true)
	set_state(RunState.RUNNING)
	wave_manager.start_next_wave()

func restart_run() -> void: start_run()

func update_wallet() -> void:
	hud.set_coins(coins)
	hud.set_gems(MetaProgression.gems + pending_gems)
	coins_changed.emit(coins)

func _on_wave_started(wave: int, spawn_plan: Array[Dictionary]) -> void:
	if state != RunState.RUNNING: return
	hud.set_wave(wave)
	hud.set_boss_wave(wave_manager.is_boss_wave())
	for entry in spawn_plan: spawn_enemy(wave, entry)

func spawn_enemy(wave: int, entry: Dictionary) -> void:
	if state != RunState.RUNNING or enemy_scene == null: return
	var enemy := enemy_scene.instantiate() as Enemy
	var archetype_id := str(entry.get("id", "normal"))
	var archetypes := ConfigManager.get_enemy_archetypes()
	var archetype: Dictionary = archetypes.get(archetype_id, archetypes.get("normal", {}))
	enemy.archetype_id = archetype_id
	enemy.stage = wave
	enemy.position = get_spawn_position()
	enemy.configure(ConfigManager.get_enemy_config(), archetype, wave, player, ConfigManager.get_int("economy", "coin_per_kill", 0), bool(entry.get("is_boss", false)))
	if enemy.is_boss: enemy.coin_reward += ConfigManager.get_int("economy", "boss_coin_reward", 30)
	enemy.died.connect(_on_enemy_died.bind(enemy.is_boss, generation))
	enemies_container.add_child(enemy)

func get_spawn_position() -> Vector2:
	var size := get_viewport_rect().size
	var margin := 56.0
	match randi_range(0, 3):
		0: return Vector2(randf_range(0.0, size.x), -margin)
		1: return Vector2(randf_range(0.0, size.x), size.y + margin)
		2: return Vector2(-margin, randf_range(0.0, size.y))
		_: return Vector2(size.x + margin, randf_range(0.0, size.y))

func _on_enemy_died(reward: int, boss: bool = false, token: int = -1) -> void:
	if state != RunState.RUNNING or player.is_dead or (token >= 0 and token != generation): return
	var gained := int(floor(reward * player.coin_reward_multiplier + 0.5))
	coins += gained
	earned_coins += gained
	wave_manager.register_enemy_defeated(boss)
	update_wallet()

func _on_wave_completed(_wave: int) -> void:
	if state != RunState.RUNNING or player.is_dead: return
	pending_gems += 5 if wave_manager.is_boss_wave() else 1
	wave_manager.retire_remaining()
	clear_combat_nodes()
	update_wallet()
	if wave_manager.current_wave >= wave_manager.total_stages:
		victory = true
		pending_gems += 10
		finish_run()
	else: offer_upgrade(true)

func offer_upgrade(advance: bool, bonus: bool = false) -> void:
	MetaProgression.checkpoint_run(run_id, coins, pending_gems)
	advance_after_choice = advance
	bonus_offer = bonus
	if not bonus:
		checkpoint += 1
		RewardedAds.set_context(run_id, checkpoint)
	set_state(RunState.SELECTING_UPGRADE)
	screen.hide()
	var choices := upgrade_manager.get_choices()
	upgrade_panel.show_choices(choices, upgrade_manager.offer_id)

func _on_upgrade_selected(id: String, offer_token: int = -1) -> void:
	if state != RunState.SELECTING_UPGRADE: return
	if offer_token >= 0 and offer_token != upgrade_manager.offer_id: return
	if id.is_empty():
		if not upgrade_manager.offered.is_empty(): return
	elif not upgrade_manager.apply_upgrade(id, offer_token): return
	upgrade_panel.hide()
	if bonus_offer:
		bonus_offer = false
		show_checkpoint()
	else: show_checkpoint()

func show_checkpoint() -> void:
	set_state(RunState.PAUSED)
	var cost := ceili(20 * pow(1.25, run_purchases))
	screen.present("BUILD STRENGTH", "Stage %d • %d Coins\nOne optional extra upgrade per checkpoint." % [wave_manager.current_wave, coins], [
		action("CONTINUE", continue_checkpoint),
		action("EXTRA UPGRADE • %d COINS" % cost, buy_extra, purchased_checkpoint == checkpoint or coins < cost or not upgrade_manager.has_eligible()),
		action("REWARDED FREE UPGRADE", func(): request_ad("free_upgrade"), not RewardedAds.available()),
		action("SETTINGS", func(): show_settings(show_checkpoint))])

func buy_extra() -> void:
	if state != RunState.PAUSED or purchased_checkpoint == checkpoint or not upgrade_manager.has_eligible(): return
	var cost := ceili(20 * pow(1.25, run_purchases))
	if coins < cost: return
	if not MetaProgression.checkpoint_run(run_id, coins - cost, pending_gems):
		screen.description_label.text = "Could not save purchase. Nothing was charged."
		return
	coins -= cost
	run_purchases += 1
	purchased_checkpoint = checkpoint
	update_wallet()
	offer_upgrade(advance_after_choice, true)

func continue_checkpoint() -> void:
	screen.hide()
	set_state(RunState.RUNNING)
	if advance_after_choice:
		advance_after_choice = false
		wave_manager.start_next_wave()

func pause_run() -> void:
	if state != RunState.RUNNING: return
	set_state(RunState.PAUSED)
	screen.present("PAUSED", "Your expedition clock is stopped.", [
		action("RESUME", resume_run), action("SETTINGS", func(): show_settings(show_pause)),
		action("END & BANK REWARDS", finish_run)])

func show_pause() -> void:
	set_state(RunState.RUNNING)
	pause_run()

func resume_run() -> void:
	screen.hide()
	set_state(RunState.RUNNING)

func _on_player_died() -> void:
	if state not in [RunState.RUNNING, RunState.SELECTING_UPGRADE]: return
	upgrade_panel.hide()
	set_state(RunState.REVIVE_OFFER)
	screen.present("SECOND CHANCE?", "Revive at 50% HP with 3 seconds of protection.\nNo ad provider is connected." if not RewardedAds.available() else "DEBUG TEST provider • no real ad", [
		action("REWARDED REVIVE", func(): request_ad("revive"), revived or not RewardedAds.available()),
		action("BANK REWARDS", finish_run)])

func finish_run() -> void:
	set_state(RunState.GAME_OVER)
	upgrade_panel.hide()
	clear_projectiles()
	if not settled:
		settled = MetaProgression.settle_run(run_id, coins, pending_gems)
	show_results()
	game_over.emit()

func show_results() -> void:
	set_state(RunState.GAME_OVER)
	hud.hide()
	var description := "Stage %d / 10\nRun: %d Coins • %d Gems\nBank: %d Coins • %d Gems" % [wave_manager.current_wave, coins, pending_gems, MetaProgression.banked_coins, MetaProgression.gems]
	if not settled: description += "\nSAVE FAILED — retry before leaving."
	screen.present("CHAPTER COMPLETE" if victory else "EXPEDITION ENDED", description, [
		action("PLAY AGAIN", start_run, not settled),
		action("RETRY SAVE", finish_run, settled),
		action("PERMANENT UPGRADES", func(): show_shop(show_results), not settled),
		action("REWARDED x2 COINS", func(): request_ad("double_coins"), not RewardedAds.available() or not settled),
		action("MAIN MENU", show_menu, not settled)])

func _on_special_pressed() -> void:
	if state == RunState.RUNNING: player.cast_nova()

func _on_chest_requested() -> void:
	if state not in [RunState.GAME_OVER, RunState.META_SHOP]: return
	if MetaProgression.buy_chest(): update_wallet()

func show_shop(back: Callable) -> void:
	return_to = back
	set_state(RunState.META_SHOP)
	hud.hide()
	upgrade_panel.hide()
	screen.present("PERMANENT UPGRADES", "Bank: %d Coins • %d Gems\nEach level: +5%% base stat next run. Max 10." % [MetaProgression.banked_coins, MetaProgression.gems], [
		action("DAMAGE %d/10 • %d GEMS" % [MetaProgression.permanent_damage_level, MetaProgression.upgrade_cost(MetaProgression.permanent_damage_level)], func(): shop_purchase("damage_level", back), MetaProgression.permanent_damage_level >= 10 or MetaProgression.gems < MetaProgression.upgrade_cost(MetaProgression.permanent_damage_level)),
		action("HP %d/10 • %d GEMS" % [MetaProgression.permanent_health_level, MetaProgression.upgrade_cost(MetaProgression.permanent_health_level)], func(): shop_purchase("health_level", back), MetaProgression.permanent_health_level >= 10 or MetaProgression.gems < MetaProgression.upgrade_cost(MetaProgression.permanent_health_level)),
		action("CHEST • 100 COINS → 5 GEMS", func(): shop_purchase("chest", back), MetaProgression.banked_coins < 100),
		action("REWARDED +20 GEMS", func(): request_ad("gems"), not RewardedAds.available()),
		action("REWARDED CHEST • 5 GEMS", func(): request_ad("chest"), not RewardedAds.available()),
		action("BACK", back)])

func shop_purchase(kind: String, back: Callable) -> void:
	var success := MetaProgression.buy_chest() if kind == "chest" else MetaProgression.buy_level(kind)
	show_shop(back)
	if success:
		GameAudio.play_cue("reward")
	else:
		screen.description_label.text += "\nPurchase failed. Nothing was charged."

func show_tutorial() -> void:
	var style := str(ConfigManager.get_section("gameplay").get("combat_style", "zombie"))
	var mechanic := "Unlock Nova to blast nearby enemies."
	if style == "space": mechanic = "Your shield regenerates after 7 safe seconds. Unlock EMP to clear nearby threats."
	elif style == "ninja": mechanic = "Your blade strikes at close range. Unlock Dash to cut through danger with brief protection."
	screen.present("HOW TO SURVIVE", "Drag the arena to move. Keyboard: WASD / arrows.\nWeapons attack automatically at nearby enemies.\nChoose a free upgrade every 45 active seconds.\n" + mechanic + " Tap its button or press Space.\nBosses guard stages 5 and 10. Dodge their windups.\nBank Gems to improve your next expedition.", [action("PLAY", start_run), action("BACK", show_menu)])

func show_settings(back: Callable) -> void:
	screen.present("SETTINGS", "Local settings • rewarded ads remain unavailable in release.", [
		action("SOUND: " + ("OFF" if AudioServer.is_bus_mute(0) else "ON"), func(): AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0)); MetaProgression.set_setting("muted", AudioServer.is_bus_mute(0)); show_settings(back)),
		action("MUSIC: " + ("ON" if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) else "OFF"), func(): var enabled := AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")); GameAudio.set_music_enabled(enabled); MetaProgression.set_setting("music", enabled); show_settings(back)),
		action("REDUCED FLASH: " + ("ON" if bool(MetaProgression.data.settings.get("reduced_flash", false)) else "OFF"), func(): MetaProgression.set_setting("reduced_flash", not bool(MetaProgression.data.settings.get("reduced_flash", false))); show_settings(back)),
		action("DEBUG REWARD TEST: " + ("ON" if RewardedAds.debug_mock else "OFF"), func(): RewardedAds.debug_mock = not RewardedAds.debug_mock; show_settings(back), not OS.is_debug_build()),
		action("BACK", back)])

func request_ad(placement: String) -> void:
	if placement == "revive" and (state != RunState.REVIVE_OFFER or revived): return
	if placement == "double_coins" and (state != RunState.GAME_OVER or not settled): return
	if placement == "free_upgrade" and (state != RunState.PAUSED or purchased_checkpoint == checkpoint or not upgrade_manager.has_eligible()): return
	if placement in ["gems", "chest"] and state != RunState.META_SHOP: return
	RewardedAds.coin_bonus = earned_coins
	ad_origin = state
	ad_request = RewardedAds.request_reward(placement)
	if ad_request.is_empty(): return
	ad_placement = placement
	set_state(RunState.AD_PENDING)
	screen.present("DEBUG TEST • NOT AN AD", "Placement: " + placement + "\nOnly Earn authorizes a reward. Cancel and Fail pay nothing.", [
		action("EARN", func(): RewardedAds.finish(ad_request, "earned")),
		action("CANCEL", func(): RewardedAds.finish(ad_request, "cancelled")),
		action("FAIL", func(): RewardedAds.finish(ad_request, "failed"))])

func _reward_earned(placement: String) -> void:
	match placement:
		"revive":
			revived = true
			player.is_dead = false
			player.current_health = player.max_health * 0.5
			player.invulnerability = 3.0
			player.health_changed.emit(player.current_health, player.max_health)
			for enemy in enemies_container.get_children():
				enemy.position += player.position.direction_to(enemy.position) * 140.0
		"free_upgrade": purchased_checkpoint = checkpoint
	update_wallet()

func _reward_finished(_id: String, status: String) -> void:
	if state != RunState.AD_PENDING: return
	if status == "earned" and ad_placement == "revive":
		resume_run()
	elif status == "earned" and ad_placement == "free_upgrade":
		offer_upgrade(advance_after_choice, true)
	elif ad_origin == RunState.GAME_OVER: show_results()
	elif ad_origin == RunState.META_SHOP: show_shop(return_to)
	elif ad_origin == RunState.REVIVE_OFFER:
		state = RunState.RUNNING
		_on_player_died()
	else: show_checkpoint()

func clear_combat_nodes() -> void:
	for enemy in enemies_container.get_children():
		enemy.set_combat_active(false)
		enemies_container.remove_child(enemy)
		enemy.queue_free()
	clear_projectiles()

func clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.get_parent().remove_child(node)
		node.queue_free()
