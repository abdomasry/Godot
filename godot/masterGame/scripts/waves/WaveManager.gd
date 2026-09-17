class_name WaveManager
extends Node

signal wave_started(wave: int, enemy_count: int)
signal wave_completed(wave: int)

var current_wave: int = 0
var enemies_remaining: int = 0
var starting_enemy_count: int = 1
var enemy_growth_per_wave: float = 1.0

func configure(stats: Dictionary) -> void:
	starting_enemy_count = int(stats.get("starting_enemy_count", 1))
	enemy_growth_per_wave = float(stats.get("enemy_growth_per_wave", 1.0))

func start_next_wave() -> void:
	current_wave += 1
	enemies_remaining = int(maxi(1, ceili(starting_enemy_count * pow(enemy_growth_per_wave, current_wave - 1))))
	wave_started.emit(current_wave, enemies_remaining)

func register_enemy_defeated() -> void:
	if enemies_remaining <= 0:
		return
	enemies_remaining -= 1
	if enemies_remaining == 0:
		wave_completed.emit(current_wave)
