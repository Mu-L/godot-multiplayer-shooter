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


# 多人远离合力计算 (排斥向量叠加)
func get_multiplayer_repulsion_vector() -> Vector2:
	var combined_force: Vector2 = Vector2.ZERO
	var valid_players = boss.big_area_players.filter(func(p): return is_instance_valid(p))

	if valid_players.is_empty():
		return Vector2.ZERO

	for player in valid_players:
		var diff = boss.global_position - player.global_position
		var dist = diff.length()
		if dist > 0.001:
			# 距离越近, 斥力越大 (与距离成反比)
			var force_magnitude = 1.0 / dist
			combined_force += diff.normalized() * force_magnitude

	return combined_force.normalized()


func _on_state_entered() -> void:
	KLogger.info("action state: 'keep away' entered")
	boss.animation_tween.play()


func _on_state_exited() -> void:
	boss.animation_tween.stop()
	boss.animation.scale = Vector2.ONE


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	# 多人综合方向计算
	boss.move_direction = get_multiplayer_repulsion_vector()
	# 无效时再看看目标
	if boss.move_direction.is_zero_approx():
		boss.move_direction = -boss.global_position.direction_to(boss.target.global_position)
	# 检测状态切换
	if boss.normal_attack_timer.is_stopped() or boss.rush_timer.is_stopped():
		boss.state_chart.send_event("to_idle")
		return
	# 一定概率尝试躲避子弹
	if boss.dodge_timer.is_stopped() and not boss.big_area_bullets.is_empty() and randf() < boss.dodge_rate:
		boss.state_chart.send_event("to_dodge")
		return

