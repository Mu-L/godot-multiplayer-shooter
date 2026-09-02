@tool
extends AtomicState


const RUSHING_TIME: float = 3.0
const TARGET_FRESH_TIME: float = 1.2

@export var boss: Boss
@export var rush_hit_collision_shape: CollisionShape2D

var charge_tween: Tween
var rushing: bool = false
var rushing_time: float = 0.0
var target_fresh: float = 0.0

func _ready() -> void:
	super()
	if multiplayer.is_server():
		state_entered.connect(_on_state_entered)
		state_exited.connect(_on_state_exited)
		state_processing.connect(_on_state_processing)
		state_physics_processing.connect(_on_state_physics_processing)


func _on_state_entered() -> void:
	KLogger.info("action state: 'rush' entered")
	rushing = false
	rushing_time = 0.0
	target_fresh = 0.0
	boss.speed_offset = -boss.current_speed
	if boss.target:
		boss.move_direction = boss.global_position.direction_to(boss.target.global_position)
		# if phase == Phase.FEAR and not small_area_players.is_empty():
		# 	rush_direction = -rush_direction # 逃跑冲刺

	KLogger.debug("start rush charge")
	boss.rpc_play_animation.rpc(&"normal_rush_charge" if boss.phase != boss.Phase.RAGE else &"rage_rush_charge")
	charge_tween = create_tween()
	charge_tween.tween_property(boss, "speed_offset", 0, 1.0).from(-boss.current_speed)


func _on_state_exited() -> void:
	if charge_tween and charge_tween.is_valid():
		charge_tween.kill()
	rush_hit_collision_shape.disabled = true
	boss.speed_offset = 0.0


func _on_state_processing(_delta: float) -> void:
	pass


func _on_state_physics_processing(delta: float) -> void:
	if not boss.rush_timer.is_stopped():
		return
	if _chart.get_expression_property("is_dead"):
		if charge_tween and charge_tween.is_valid():
			charge_tween.kill()
		rush_hit_collision_shape.disabled = true
		boss.speed_offset = 0.0
		return
	if not rushing and not charge_tween.is_running():
		rushing = true
		rush_hit_collision_shape.disabled = false
		KLogger.debug("rushing!")
		boss.speed_offset = boss.current_speed * 2.0
		boss.rpc_play_animation.rpc(&"normal_rush" if boss.phase != boss.Phase.RAGE else &"rage_rush")
		return
	if rushing:
		rushing_time += delta
		target_fresh += delta
		if rushing_time > RUSHING_TIME:
			KLogger.debug("rush end!")
			rush_hit_collision_shape.disabled = true
			boss.speed_offset = 0.0
			boss.rush_timer.start()
			boss.state_chart.send_event("to_idle")
		if target_fresh > TARGET_FRESH_TIME:
			target_fresh = 0.0
			if boss.target:
				boss.move_direction = boss.global_position.direction_to(boss.target.global_position)