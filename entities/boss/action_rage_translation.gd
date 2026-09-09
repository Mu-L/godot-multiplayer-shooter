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


func play_rage_effect() -> void:
	# 默认所有peer上执行
	# 打开无敌盾
	KLogger.debug("boss open shield!!!")
	boss.open_shield()
	# 吼叫，光波, 推开所有player (物理效果已经限制仅server执行)
	var radius: float = 300.0
	var duration: float = 0.7
	var times: int = 20
	var interval: float = 0.15
	var push_force: float = 350.0
	var total_time: float = duration + (times - 1) * interval
	boss.trigger_ring(radius, duration, times, interval, push_force)
	# 镜头抖动
	GameCamera.strong_shake(total_time)
	# 动画结束后关闭护盾
	await get_tree().create_timer(total_time).timeout
	KLogger.debug("boss close shield!!!")
	boss.close_shield()
	# TODO 音效


func _on_state_entered() -> void:
	KLogger.info("action state: 'rage translation' entered")
	boss.phase = boss.Phase.RAGE_TRANSLATION
	boss.is_check_flip = false
	boss.hurtbox_shape.disabled = true
	boss.move_direction = Vector2.ZERO
	boss.velocity = Vector2.ZERO
	# 形象切换
	boss.rpc_play_animation.rpc(&"normal_idle")
	# 抖动动画
	var intensity: float = 5.0
	var steps: int = 50
	var step_time: float = 0.02
	boss.rpc_play_shake_animation.rpc(intensity, steps, step_time)
	await get_tree().create_timer((steps + 1) * step_time).timeout
	# 状态转换动画
	boss.rpc_play_animation.rpc(&"rage_transform")
	# 动画播放完毕转换状态
	await boss.animation_player.animation_finished
	# 狂暴阶段血量回复
	boss.healing(RAGE_HEALING_RATIO)
	# 阶段切换
	boss.phase = boss.Phase.RAGE
	boss.state_chart.send_event(&"to_idle")


func _on_state_exited() -> void:
	KLogger.info("action state: 'rage translation' exited")
	boss.is_check_flip = true
	boss.hurtbox_shape.disabled = false


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(_delta: float) -> void:
	pass
