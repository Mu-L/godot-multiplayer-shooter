@tool
extends AtomicState

const ANIM_TIME: float = 2.0
const MAX_HEIGHT: float = -500.0
const STATE_TIME: float = ANIM_TIME + 1.0

@export var boss: Boss

var cur_time: float = 0.0
var original_shadow_scale: Vector2
var original_shadow_modulate: Color
var original_visual_pos: Vector2

func _ready() -> void:
	super()
	state_entered.connect(_on_state_entered)
	state_exited.connect(_on_state_exited)
	state_processing.connect(_on_state_processing)
	state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'spawn' entered")
	original_shadow_scale = boss.shadow.scale
	original_shadow_modulate = boss.shadow.self_modulate
	original_visual_pos = boss.visual.position
	boss.shadow.scale = original_shadow_scale * 0.2
	boss.shadow.self_modulate = Color.TRANSPARENT
	boss.visual.position.y = MAX_HEIGHT
	# 禁用碰撞, 禁用伤害
	boss.collision_shape.disabled = true
	boss.hurtbox_shape.disabled = true
	# 播放动画
	boss.animation_player.play(&"jump_flying")
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(boss.shadow, "scale", original_shadow_scale, ANIM_TIME)
	tween.tween_property(boss.shadow, "self_modulate", original_shadow_modulate, ANIM_TIME)
	tween.tween_property(boss.visual, "position", original_visual_pos, ANIM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	KLogger.info("action spawn tween finished!!")
	boss.animation_player.play(&"jump_landing")
	var push_radius: float = 200.0
	var push_force: float = 800.0
	var push_duration: float = 0.5
	# 播放特效 & 施加推力
	boss.trigger_ring(push_radius, push_duration, 1, 0.15, push_force)
	# 相机震动
	GameCamera.strong_shake()


func _on_state_exited() -> void:
	KLogger.info("action state: 'spawn' exited")
	# 启用碰撞, 启用伤害
	boss.collision_shape.disabled = false
	boss.hurtbox_shape.disabled = false
	boss.animation_player.play(&"normal_idle")


func _on_state_processing(delta: float) -> void:
	cur_time += delta
	if cur_time >= STATE_TIME and multiplayer.is_server():
		boss.state_chart.send_event(&"to_idle")


func _on_state_physics_processing(_delta: float) -> void:
	pass
