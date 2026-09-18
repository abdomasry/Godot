class_name ScreenPanel
extends Control

const SURFACE := Color("14232b")
const TEXT := Color("edf5ec")
const ACCENT := Color("d6ef88")
var rows: VBoxContainer
var title_label: Label
var description_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.055, 0.065, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 16)
	scroll.add_child(rows)
	hide()

func present(title: String, description: String, actions: Array[Dictionary]) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	title_label = label(title, 44, ACCENT)
	description_label = label(description, 28, TEXT)
	for action in actions:
		var button := Button.new()
		button.text = action.get("label", "Continue")
		button.custom_minimum_size.y = 104
		button.add_theme_font_size_override("font_size", 28)
		button.add_theme_color_override("font_color", TEXT)
		var style := StyleBoxFlat.new()
		style.bg_color = SURFACE
		style.border_color = Color("668985")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		style.content_margin_left = 16
		style.content_margin_right = 16
		button.add_theme_stylebox_override("normal", style)
		var pressed := style.duplicate()
		pressed.bg_color = Color("36554e")
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover", pressed)
		var focus := style.duplicate()
		focus.border_color = ACCENT
		focus.set_border_width_all(4)
		button.add_theme_stylebox_override("focus", focus)
		button.disabled = action.get("disabled", false)
		if action.has("callback"): button.pressed.connect(action.callback)
		rows.add_child(button)
	show()
	for child in rows.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.custom_minimum_size.y = 72
	rows.add_child(node)
	return node
