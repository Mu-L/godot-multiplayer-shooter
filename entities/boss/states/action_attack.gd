@tool
extends AtomicState

@export var boss: Boss


func _ready() -> void:
	super()
	state_entered.connect(_on_state_entered)
	state_exited.connect(_on_state_exited)
	state_processing.connect(_on_state_processing)
	state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'attack' entered")
	var attack: BossNormalAttack = boss.attack_scene.instantiate()
	attack.boss = boss
	attack.attack_ended.connect(func() -> void:
		KLogger.debug("attack ended")
		boss.state_chart.send_event("to_idle")
	)
	boss.speed_offset = -(boss.current_speed * 0.6) # 攻击状态减速
	attack.position = boss.visual.position
	boss.add_child(attack)


func _on_state_exited() -> void:
	KLogger.info("action state: 'attack' exited")
	boss.speed_offset = 0
	boss.normal_attack_timer.start()


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	if boss.target:
		boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
	else:
		boss.move_direction = Vector2.ZERO
