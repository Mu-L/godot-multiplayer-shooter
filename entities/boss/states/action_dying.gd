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
	KLogger.info("action state: 'dying' entered")
	boss.state_chart.set_expression_property("is_dead", true)
	boss.hurtbox_shape.disabled = true
	boss.collision_shape.disabled = true
	boss.move_direction = Vector2.ZERO
	boss.animation_player.play("dying")
	boss.is_check_flip = false
	await boss.animation_player.animation_finished
	await get_tree().create_timer(2.0).timeout
	GameEvents.emit_enemy_died()
	queue_free()


func _on_state_exited() -> void:
	pass


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
