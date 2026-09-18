class_name UpgradePanel
extends Control

signal upgrade_selected(upgrade_id: String, offer_token: int)
var offer_token := -1

@onready var buttons: Array[Button] = [$Center/Panel/Margin/Choices/Damage, $Center/Panel/Margin/Choices/AttackSpeed, $Center/Panel/Margin/Choices/Health]

var options: Array[Dictionary] = []

func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("13242d")
	panel_style.border_color = Color("628986")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	$Center/Panel.add_theme_stylebox_override("panel", panel_style)
	for index in range(buttons.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203942")
		style.border_color = [Color("d6ef88"), Color("75d7ec"), Color("d8adf2")][index]
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.content_margin_left = 12
		style.content_margin_right = 12
		buttons[index].add_theme_stylebox_override("normal", style)
		var highlighted := style.duplicate()
		highlighted.bg_color = Color("36565f")
		highlighted.set_border_width_all(4)
		buttons[index].add_theme_stylebox_override("hover", highlighted)
		buttons[index].add_theme_stylebox_override("pressed", highlighted)
		buttons[index].add_theme_stylebox_override("focus", highlighted)
		buttons[index].add_theme_font_size_override("font_size", 26)
		buttons[index].pressed.connect(select.bind(index))
	hide()

func show_choices(choices: Array[Dictionary], token: int = -1) -> void:
	offer_token = token
	options = choices
	if options.is_empty(): options.append({"id":"", "display_name":"Continue", "description":"All available upgrades are complete."})
	for index in range(buttons.size()):
		var is_visible := index < options.size()
		buttons[index].visible = is_visible
		if is_visible:
			var option := options[index]
			buttons[index].text = "%s\n%s" % [option.get("display_name", "Upgrade"), option.get("description", "")]
	show()
	buttons[0].grab_focus()

func select(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	upgrade_selected.emit(str(options[index].get("id", "")), offer_token)
