class_name EnemySpawnComponent
extends Node

const ENEMY = preload("uid://pu2c45uixpy0")

const BASE_ROUND_TIME: float = 10
const ROUND_TIME_GROWTH: float = 5
const BASE_MIN_SPAWN_INTERVAL: float = 2.0
const BASE_MAX_SPAWN_INTERVAL: float = 5.0
const SPAWN_INTERVAL_GROWTH: float = -0.2

@export var spawn_root: Node2D
@export var spawn_rect: ReferenceRect

var round_count: int = 0
var round_min_spawn_interval: float = BASE_MIN_SPAWN_INTERVAL
var round_max_spawn_interval: float = BASE_MAX_SPAWN_INTERVAL
var enemy_count: int = 0

@onready var spawn_timer: Timer = $SpawnTimer
@onready var round_timer: Timer = $RoundTimer

func _ready() -> void:
	if is_multiplayer_authority():
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		round_timer.timeout.connect(_on_round_timer_timeout)
		GameEvents.enemy_died.connect(_on_enemy_died)
		_start_round()
	else:
		spawn_timer.process_mode = Node.PROCESS_MODE_DISABLED
		round_timer.process_mode = Node.PROCESS_MODE_DISABLED


func _start_round() -> void:
	round_count += 1
	print("Round %s start" % round_count)
	round_min_spawn_interval = BASE_MIN_SPAWN_INTERVAL + (round_count - 1) * SPAWN_INTERVAL_GROWTH
	round_max_spawn_interval = BASE_MAX_SPAWN_INTERVAL + (round_count - 1) * SPAWN_INTERVAL_GROWTH
	round_timer.start(BASE_ROUND_TIME + (round_count - 1) * ROUND_TIME_GROWTH)
	spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))


func _check_round_completed() -> void:
	if !round_timer.is_stopped():
		return
	if enemy_count == 0:
		print("Round %s completed!" % round_count)
		_start_round()


func _get_random_position() -> Vector2:
	var pos := Vector2(
		randf_range(0, spawn_rect.size.x),
		randf_range(0, spawn_rect.size.y),
	)
	pos += spawn_rect.global_position
	return pos


func _on_spawn_timer_timeout() -> void:
	var enemy := ENEMY.instantiate() as Node2D
	enemy.global_position = _get_random_position()
	#print("[peer %s] enemy spawn pos: %s" % [multiplayer.get_unique_id(), enemy.global_position])
	spawn_root.add_child(enemy, true)
	enemy_count += 1
	spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))


func _on_round_timer_timeout() -> void:
	print("Round %s end" % round_count)
	spawn_timer.stop()
	_check_round_completed()


func _on_enemy_died() -> void:
	enemy_count -= 1
	_check_round_completed()
