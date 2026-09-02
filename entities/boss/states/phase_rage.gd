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
	KLogger.info("phase state: 'rage' entered")
	boss.phase = boss.Phase.RAGE
	boss.current_speed = boss.RAGE_SPEED
	# 狂暴阶段 CD 减半
	boss.rush_timer.wait_time = 4.0
	boss.jump_timer.wait_time = 5.0
	boss.normal_attack_timer.wait_time = 0.6


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
