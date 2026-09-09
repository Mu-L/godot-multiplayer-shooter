@tool
extends AtomicState

enum {
	CHARGE,
	FLYING,
	LANDING,
}

const DOUBLE_JUMP_RATIO: float = 0.3
const JUMP_HEIGHT: float = -100.0
const JUMP_CHARGE_TIME: float = 0.5
const JUMP_FLY_TIME: float = 0.7
const LANDING_KEEP_TIME: float = 0.3

const JUMP_HURT_RADIUS: float = 120.0
const JUMP_MAX_DAMAGE: float = 12.0

@export var boss: Boss
@export var range_indicator_scene: PackedScene

var jump_times: int
var jump_target_pos: Vector2
var state: int = CHARGE
var timer: float = 0.0

var origin_animation_pos: Vector2
var tweens: Array[Tween] = []
var indicator: RangeIndicator

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)
	await owner.ready
	origin_animation_pos = boss.animation.position


@rpc("authority", "call_local", "reliable")
func _rpc_play_jump_animation(target_pos: Vector2) -> void:
	origin_animation_pos = boss.animation.position
	boss.animation_player.play(&"jump_flying")
	KLogger.debug("peer %d: play jump fly animation!" % multiplayer.get_unique_id())
	# Godot State Charts中, 未激活的State节点的Process Mode被设置为disable了, Client未同步状态机状态, 创建的Tween无法运行
	var height_tween: Tween = boss.create_tween()
	height_tween.tween_property(boss.animation, ^"position", origin_animation_pos + Vector2(0, JUMP_HEIGHT), JUMP_FLY_TIME * 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	height_tween.chain().tween_property(boss.animation, ^"position", origin_animation_pos, JUMP_FLY_TIME * 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(JUMP_FLY_TIME * 0.7)
	tweens.append(height_tween)
	# 技能范围指示
	indicator = range_indicator_scene.instantiate()
	indicator.size = Vector2.ONE * JUMP_HURT_RADIUS * 2.0
	indicator.position = target_pos
	boss.get_parent().add_child(indicator)
	var range_tween: Tween = boss.create_tween()
	range_tween.tween_property(indicator, "progress", 1.0, JUMP_FLY_TIME)
	range_tween.tween_callback(func() -> void:
		if indicator:
			indicator.queue_free()
	)
	tweens.append(range_tween)
	if multiplayer.is_server():
		# 位置的移动只由服务端执行
		var pos_tween: Tween = boss.create_tween()
		pos_tween.tween_property(boss, ^"global_position", target_pos, JUMP_FLY_TIME)
		height_tween.finished.connect(_on_jump_fly_complete)
		tweens.append(pos_tween)


@rpc("authority", "call_local", "reliable")
func _rpc_jump_state_exited() -> void:
	# 关闭播放中的动画
	for tween in tweens:
		if tween:
			tween.kill()
	tweens.clear()
	# 显示资源属性归位
	boss.animation.position = origin_animation_pos
	# 关闭技能显示
	if indicator:
		indicator.queue_free()


func _on_state_entered() -> void:
	KLogger.info("action state: 'jump' entered")
	KLogger.info("target is: %s" % boss.target.name)
	boss.move_direction = Vector2.ZERO
	jump_target_pos = boss.target.global_position
	jump_times = 2 if randf() < DOUBLE_JUMP_RATIO else 1
	# 蓄力
	state = CHARGE
	timer = 0.0
	boss.rpc_play_animation(&"jump_charge")


func _on_state_exited() -> void:
	_rpc_jump_state_exited.rpc()
	boss.jump_timer.start()


func _on_state_processing(delta: float) -> void:
	timer += delta
	match state:
		CHARGE:
			if timer > JUMP_CHARGE_TIME:
				boss.hurtbox_shape.disabled = true
				state = FLYING
				timer = 0
				if boss.target:
					jump_target_pos = boss.target.global_position
				_rpc_play_jump_animation.rpc(jump_target_pos)
		LANDING:
			if timer > LANDING_KEEP_TIME:
				jump_times -= 1
				if jump_times <= 0:
					boss.state_chart.send_event(&"to_idle")
				else:
					boss.hurtbox_shape.disabled = true
					state = FLYING
					timer = 0
					if boss.target:
						jump_target_pos = boss.target.global_position
					_rpc_play_jump_animation.rpc(jump_target_pos)
		_:
			pass


func _on_state_physics_processing(_delta: float) -> void:
	pass


func _on_jump_fly_complete() -> void:
	# 可能不执行（动作未完成，被打断，比如死亡）
	# 所有peer执行
	boss.animation_player.play(&"jump_landing")
	# 相机震动
	GameCamera.strong_shake(0.5)
	if multiplayer.is_server():
		timer = 0
		state = LANDING
		boss.hurtbox_shape.disabled = false
		# 造成范围伤害
		boss.jump_hurt_players(JUMP_HURT_RADIUS, JUMP_MAX_DAMAGE)
