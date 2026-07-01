extends Control

@export var enemy_spawn_component: EnemySpawnComponent

@onready var round_label: Label = %RoundLabel
@onready var timer_label: Label = %TimerLabel

func _ready() -> void:
	enemy_spawn_component.round_changed.connect(_on_round_changed)
	enemy_spawn_component.bonus_round_started.connect(_on_bonus_round_started)
	enemy_spawn_component.boss_round_started.connect(_on_boss_round_started)


func _process(_delta: float) -> void:
	var time_left := enemy_spawn_component.get_round_time_left()
	timer_label.text = str(ceili(time_left))


func _on_round_changed(round_count: int) -> void:
	round_label.text = tr("ROUND_COUNT_INFO") % round_count


func _on_bonus_round_started() -> void:
	round_label.text = "BONUS ROUND"
	SoundManager.play_round_win()


func _on_boss_round_started() -> void:
	round_label.text = "BOSS"
