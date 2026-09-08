@tool
extends AtomicState


## 进入愤怒阶段回血比例
const RAGE_HEALING_RATIO: float = 0.2

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
	# 狂暴阶段血量回复
	# TODO 回血特效展示
	boss.healing(RAGE_HEALING_RATIO)


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
