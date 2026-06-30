class_name HealthComponent
extends Node

signal health_changed(max_value: float, current_value: float)
signal health_depleted

@export var max_health: float = 5

var current_health: float = max_health:
	get:
		return current_health
	set(value):
		if not is_equal_approx(value, current_health):
			current_health = value
			health_changed.emit(max_health, current_health)


func _ready() -> void:
	if is_multiplayer_authority():
		current_health = max_health


func take_damage(damage: float) -> void:
	current_health = clamp(current_health - damage, 0, max_health)
	if is_zero_approx(current_health):
		health_depleted.emit()


func healing(value: float) -> void:
	current_health = clamp(current_health + value, 0, max_health)


func reset(health: float = -1) -> void:
	if health < 0:
		current_health = max_health
	else:
		current_health = clamp(health, 1.0, max_health)


## 更新血量上限, 可选择是否回满差额
func set_max_health(new_max: float, heal_delta: bool = true) -> void:
	var diff: float = new_max - max_health
	max_health = new_max
	if heal_delta and diff > 0:
		healing(diff)
