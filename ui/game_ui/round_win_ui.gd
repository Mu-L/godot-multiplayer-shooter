class_name RoundWinUI
extends Control

var tween: Tween

@onready var label: Label = $Label


func show_win_tip() -> void:
	visible = true
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_loops(10)
	tween.tween_property(label, "rotation_degrees", -18.0, 0.2)
	tween.tween_property(label, "rotation_degrees", -12.0, 0.4)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.1)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.5)


func hide_win_tip() -> void:
	visible = false
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()
