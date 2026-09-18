class_name GameOverPanel
extends Control

signal restart_requested
signal chest_requested

@onready var summary: Label = $Center/Panel/Margin/Rows/Summary
@onready var restart: Button = $Center/Panel/Margin/Rows/Restart
@onready var chest: Button = $Center/Panel/Margin/Rows/Chest

func _ready() -> void:
	restart.pressed.connect(restart_requested.emit)
	chest.pressed.connect(chest_requested.emit)
	hide()

func show_result(wave: int, coins: int, gems: int) -> void:
	summary.text = "Wave %d • Coins %d • Gems %d" % [wave, coins, gems]
	chest.disabled = false
	show()
