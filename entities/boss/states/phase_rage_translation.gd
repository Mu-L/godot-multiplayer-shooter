@tool
extends AtomicState

@export var boss: Boss

# TODO 该状态无敌效果, 进入时禁用hurtbox, 退出时恢复hurtbox, 视觉效果补充?
# TODO 且不执行任何动作, 强制切换idle状态, 并且idle中判断phase

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("phase state: 'rage translation' entered")
	boss.phase = boss.Phase.RAGE_TRANSLATION
	boss.velocity = Vector2.ZERO
	boss.rpc_play_animation.rpc(&"rage_transform")
	# 动画播放完毕后触发切入 Rage
	await boss.animation_player.animation_finished
	boss.state_chart.send_event("to_rage_phase")


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
