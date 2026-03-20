extends CharacterBody2D

@onready var track_timer: Timer = $TrackTimer
@onready var health_component: HealthComponent = $HealthComponent
@onready var visual: Node2D = $Visual

var track_target: Vector2
var has_track_target: bool = false

var is_spawning: bool = false

func _ready() -> void:
	if is_multiplayer_authority():
		track_timer.timeout.connect(_on_track_timer_timeout)
		health_component.health_depleted.connect(_on_health_depleted)
		_update_track_target()
	else:
		track_timer.process_mode = Node.PROCESS_MODE_DISABLED
	_play_spawn_animation()


func _process(_delta: float) -> void:
	if is_multiplayer_authority() and not is_spawning:
		if has_track_target:
			velocity = global_position.direction_to(track_target) * 40
			move_and_slide()
	if not is_spawning:
		_update_direction()


func _play_spawn_animation() -> void:
	is_spawning = true
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2.ONE, 0.4)\
		.from(Vector2.ZERO)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	tween.finished.connect(func():
		is_spawning = false
	)


func _update_direction() -> void:
	visual.scale = Vector2.ONE\
		if track_target.x > global_position.x\
		else Vector2(-1, 1)


func _update_track_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var min_squared_distance: float
	var track_player: Node2D = null
	for player in players:
		if track_player == null:
			track_player = player
			min_squared_distance = track_player.global_position.distance_squared_to(global_position)
		var squared_distance = player.global_position.distance_squared_to(global_position)
		if squared_distance < min_squared_distance:
			min_squared_distance = squared_distance
			track_player = player
	if track_player != null:
		track_target = track_player.global_position
		has_track_target = true
	else:
		has_track_target = false


func _on_track_timer_timeout() -> void:
	_update_track_target()


func _on_health_depleted() -> void:
	GameEvents.emit_enemy_died()
	queue_free()
