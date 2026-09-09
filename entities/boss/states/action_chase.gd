@tool
extends AtomicState

const MAX_CHASE_TIME: float = 5.0

@export var boss: Boss

var cur_time: float = 0.0

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'chase' entered")
	cur_time = 0.0
	if not boss.target or boss.target.is_dead:
		boss.update_target()
		KLogger.debug("chase target updated to %s!!!" % boss.target.name)
	KLogger.debug("chase target: %s" % boss.target.name)
	boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
	boss.speed_offset = boss.current_speed * 0.2
	boss.rpc_play_move_tween.rpc(true)


func _on_state_exited() -> void:
	boss.rpc_play_move_tween.rpc(false)
	boss.animation.scale = Vector2.ONE
	cur_time = 0.0


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	cur_time += _delta
	# 尝试靠近目标
	if boss.target:
		if boss.global_position.distance_squared_to(boss.target.global_position) > 64.0:
			boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
		else:
			boss.move_direction = Vector2.ZERO
		# 进入近身范围或 CD 转好时交还给 Idle 重新仲裁
		if (not boss.big_area_players.is_empty() and boss.rush_timer.is_stopped()) \
			or (not boss.small_area_players.is_empty() and boss.normal_attack_timer.is_stopped()):
				boss.state_chart.send_event(&"to_idle")
				return
		# 超时检测
		if cur_time > MAX_CHASE_TIME:
			KLogger.info("chase timeout!!!")
			boss.state_chart.send_event(&"to_idle")
	# 一定概率尝试躲避子弹
	if boss.dodge_timer.is_stopped() and not boss.big_area_bullets.is_empty() and randf() < boss.dodge_rate:
		boss.state_chart.send_event(&"to_dodge")
		return
