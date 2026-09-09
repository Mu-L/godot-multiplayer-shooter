@tool
extends AtomicState

const FEAR_DODGE_SHIELD_RATIO: float = 0.7
const DODGE_SHIELD_TIME: float = 1.0

@export var boss: Boss
@export var dodge_shield: PackedScene


var dodge_speed_ratio_offset: float = 5.0       # 闪避速度倍率
var dodge_duration: float = 0.35     # 闪避持续时间 (秒)
var dodge_speed: float

var dodge_timer_elapsed: float

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'dodge' entered")
	dodge_timer_elapsed = 0.0
	boss.speed_offset = boss.current_speed * dodge_speed_ratio_offset
	dodge_speed = boss.speed_offset + boss.current_speed
	boss.rpc_play_move_tween.rpc(true)
	# 向目标横向远离
	var dir = Vector2.ZERO
	if boss.target:
		dir = boss.target.global_position.direction_to(boss.global_position)
		dir.rotated(deg_to_rad(90 if randf() < 0.5 else -90))
	if dir == Vector2.ZERO:
		# 没有明确危险弹道时, 随机侧移或朝当前朝向垂直侧移
		dir = Vector2.UP.rotated(randf() * TAU)
	boss.move_direction = dir
	# fear状态, 一定几率闪避时套盾规避伤害
	if boss.phase == boss.Phase.FEAR and randf() < FEAR_DODGE_SHIELD_RATIO:
		boss.rpc_dodge_shield.rpc(DODGE_SHIELD_TIME)


func _on_state_exited() -> void:
	boss.speed_offset = 0
	boss.rpc_play_move_tween.rpc(false)
	boss.animation.scale = Vector2.ONE
	boss.dodge_timer.start()


func _on_state_processing(delta: float) -> void:
	dodge_timer_elapsed += delta
	# 速度平滑指数衰减 (营造短促冲刺感)
	boss.speed_offset -= (dodge_speed / dodge_duration) * delta

	# 动作完成, 退出回到 Idle
	if dodge_timer_elapsed >= dodge_duration:
		boss.state_chart.send_event(&"to_idle")


func _on_state_physics_processing(_delta: float) -> void:
	pass
