class_name BossHp
extends MarginContainer


@export var progress_bar: TextureProgressBar


var value: float:
	get:
		return progress_bar.value
	set(v):
		progress_bar.value = v


func _ready() -> void:
	hide()
	if multiplayer.is_server():
		multiplayer.server_disconnected.connect(hide)
		GameEvents.game_ended.connect(hide)
		GameEvents.boss_spawned.connect(_on_boss_spawned)
		GameEvents.boss_died.connect(hide)
		GameEvents.boss_health_changed.connect(_on_health_changed)


func _on_boss_spawned() -> void:
	value = 1.0
	show()


func _on_health_changed(cur: float, full: float) -> void:
	value = cur / full
