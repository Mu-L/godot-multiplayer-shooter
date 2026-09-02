@tool
extends AtomicState

@export var boss: Boss


func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'chase' entered")
	if not boss.target:
		var dis_sq: float = -1.0
		for player: Player in get_tree().get_nodes_in_group("player"):
			if dis_sq < 0:
				dis_sq = boss.global_position.distance_squared_to(player.global_position)
				boss.target = player
			elif dis_sq < boss.global_position.distance_squared_to(player.global_position):
				boss.target = player
	boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
	boss.speed_offset = boss.current_speed * 0.2
	boss.animation_tween.play()


func _on_state_exited() -> void:
	boss.animation_tween.stop()
	boss.animation.scale = Vector2.ONE


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	# 尝试靠近目标
	if boss.target != null:
		if boss.global_position.distance_squared_to(boss.target.global_position) > 4.0:
			boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
		else:
			boss.move_direction = Vector2.ZERO
		# 进入近身范围或 CD 转好时交还给 Idle 重新仲裁
		if (not boss.big_area_players.is_empty() and boss.rush_timer.is_stopped()) \
			or (not boss.small_area_players.is_empty() and boss.normal_attack_timer.is_stopped()):
				boss.state_chart.send_event("to_idle")
				return
	# 一定概率尝试躲避子弹
	if boss.dodge_timer.is_stopped() and not boss.big_area_bullets.is_empty() and randf() < boss.dodge_rate:
		boss.state_chart.send_event("to_dodge")
		return
