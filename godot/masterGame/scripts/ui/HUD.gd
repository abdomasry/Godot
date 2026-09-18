class_name HUD
extends Control

signal special_pressed

@onready var health_label: Label = $Margin/Rows/Health
@onready var coins_label: Label = $Margin/Rows/Coins
@onready var wave_label: Label = $Margin/Rows/Wave
@onready var enemies_label: Label = $Margin/Rows/Enemies
@onready var boss_label: Label = $BossWave
@onready var hint_label: Label = $MoveHint
@onready var gems_label: Label = $Margin/Rows/Gems
@onready var special_button: Button = $Special
var currency_name := "Coins"

func _ready() -> void:
	for label in $Margin/Rows.get_children():
		if label is Label:
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_shadow_color", Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
	special_button.add_theme_font_size_override("font_size", 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203942")
	style.border_color = Color("75d7ec")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	special_button.add_theme_stylebox_override("normal", style)
	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color("14252d")
	disabled_style.border_color = Color("475e68")
	special_button.add_theme_stylebox_override("disabled", disabled_style)
	special_button.pressed.connect(special_pressed.emit)
	special_button.disabled = true

func set_player_health(current: float, maximum: float) -> void:
	health_label.text = "HP  %d / %d" % [roundi(current), roundi(maximum)]

func set_coins(total: int) -> void:
	coins_label.text = "%s  %d" % [currency_name, total]

func set_wave(wave: int) -> void:
	wave_label.text = "Wave  %d" % wave

func set_enemies_remaining(count: int) -> void:
	enemies_label.text = "Enemies  %d" % count

func set_boss_wave(active: bool) -> void:
	boss_label.visible = active

func set_currency_name(currency_name: String) -> void:
	self.currency_name = currency_name
	coins_label.text = "%s  0" % currency_name

func set_move_hint_visible(visible: bool) -> void:
	hint_label.visible = visible

func set_gems(total: int) -> void:
	gems_label.text = "Gems  %d" % total

func set_special_ready(ready: bool) -> void:
	special_button.disabled = not ready
	special_button.text = "NOVA" if ready else "NOVA • CHARGING"
