class_name HUD
extends Control

@onready var health_label: Label = $Margin/Rows/Health
@onready var coins_label: Label = $Margin/Rows/Coins
@onready var wave_label: Label = $Margin/Rows/Wave
@onready var enemies_label: Label = $Margin/Rows/Enemies
@onready var game_over_label: Label = $GameOver

func set_player_health(current: float, maximum: float) -> void:
	health_label.text = "HP  %d / %d" % [roundi(current), roundi(maximum)]

func set_coins(total: int) -> void:
	coins_label.text = "Coins  %d" % total

func set_wave(wave: int) -> void:
	wave_label.text = "Wave  %d" % wave

func set_enemies_remaining(count: int) -> void:
	enemies_label.text = "Enemies  %d" % count

func show_game_over() -> void:
	game_over_label.show()
