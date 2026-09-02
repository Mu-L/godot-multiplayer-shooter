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


# 清理无效引用 (防止子弹在 Area 销毁未触发 exited)
func _clean_invalid_targets() -> void:
	boss.big_area_bullets = boss.big_area_bullets.filter(func(b): return is_instance_valid(b))
	boss.big_area_players = boss.big_area_players.filter(func(p): return is_instance_valid(p))
	boss.small_area_players = boss.small_area_players.filter(func(p): return is_instance_valid(p))


func _normal_idle_decide() -> void:
	if not boss.small_area_players.is_empty() and boss.normal_attack_timer.is_stopped():
		boss.state_chart.send_event("to_attack")
		return
	if not boss.big_area_players.is_empty() and boss.rush_timer.is_stopped():
		boss.state_chart.send_event("to_rush")
		return
	if boss.normal_attack_timer.is_stopped() or boss.rush_timer.is_stopped():
		boss.state_chart.send_event("to_chase")
		return
	boss.state_chart.send_event("to_keep_away")


func _rage_idle_decide() -> void:
	if boss.jump_timer.is_stopped():
		boss.state_chart.send_event("to_jump")
		return
	if not boss.small_area_players.is_empty() and boss.normal_attack_timer.is_stopped():
		boss.state_chart.send_event("to_attack")
		return
	if boss.rush_timer.is_stopped():
		boss.state_chart.send_event("to_rush")
		return
	boss.state_chart.send_event("to_chase")


func _fear_idle_decide() -> void:
	if not boss.small_area_players.is_empty() and boss.rush_timer.is_stopped():
		# 近身危机时冲撞逃跑
		boss.state_chart.send_event("to_rush")
		return
	if boss.shoot_timer.is_stopped():
		boss.state_chart.send_event("to_shoot")
		return
	boss.state_chart.send_event("to_keep_away")


func _on_state_entered() -> void:
	KLogger.info("action state: 'idle' entered")
	boss.rpc_play_animation.rpc(&"normal_idle")
	boss.move_direction = Vector2.ZERO
	boss.speed_offset = 0


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	# 行为决策
	_clean_invalid_targets()
	match boss.phase:
		boss.Phase.NORMAL:
			_normal_idle_decide()
		boss.Phase.RAGE:
			_rage_idle_decide()
		boss.Phase.FEAR:
			_fear_idle_decide()


func _on_state_physics_processing(_delta: float) -> void:
	pass
