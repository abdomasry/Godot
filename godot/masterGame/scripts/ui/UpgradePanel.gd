class_name UpgradePanel
extends Control

signal upgrade_selected(upgrade_id: String)

@onready var damage_button: Button = $Center/Panel/Margin/Choices/Damage
@onready var attack_speed_button: Button = $Center/Panel/Margin/Choices/AttackSpeed
@onready var health_button: Button = $Center/Panel/Margin/Choices/Health

func _ready() -> void:
	damage_button.pressed.connect(select.bind("damage"))
	attack_speed_button.pressed.connect(select.bind("attack_speed"))
	health_button.pressed.connect(select.bind("health"))
	hide()

func show_choices(upgrades: Dictionary) -> void:
	damage_button.text = "Damage +%s" % upgrades.get("damage", {}).get("increase", 0)
	attack_speed_button.text = "Attack Speed +%s" % upgrades.get("attack_speed", {}).get("increase", 0)
	health_button.text = "Max Health +%s" % upgrades.get("health", {}).get("increase", 0)
	show()

func select(upgrade_id: String) -> void:
	hide()
	upgrade_selected.emit(upgrade_id)
