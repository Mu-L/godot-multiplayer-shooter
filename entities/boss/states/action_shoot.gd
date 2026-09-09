@tool
extends AtomicState

const ATTACK_INTERVAL: float = 0.5

@export var boss: Boss

var shoot_time: int
var timer: float

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'shoot' entered")
	timer = 0.0
	shoot_time = 0
	boss.speed_offset = -0.5 * boss.current_speed
	# 第一次攻击
	var aim_vector: Vector2 = boss.global_position.direction_to(boss.target.global_position)
	boss.shoot_attack(1 if randf() < 0.7 else 3, aim_vector)
	shoot_time += 1


func _on_state_exited() -> void:
	boss.speed_offset = 0
	boss.shoot_timer.start()


func _on_state_processing(delta: float) -> void:
	if shoot_time <= 0:
		return
	timer += delta
	if timer > ATTACK_INTERVAL:
		# 第二次攻击
		var aim_vector: Vector2 = boss.global_position.direction_to(boss.target.global_position)
		boss.shoot_attack(3 if randf() < 0.7 else 1, aim_vector)
		shoot_time = 0
		boss.state_chart.send_event(&"to_idle")


func _on_state_physics_processing(_delta: float) -> void:
	pass
