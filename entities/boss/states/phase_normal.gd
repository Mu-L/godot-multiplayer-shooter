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
	KLogger.info("phase state: 'normal' entered")
	boss.phase = boss.Phase.NORMAL
	boss.current_speed = boss.NORMAL_SPEED


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
