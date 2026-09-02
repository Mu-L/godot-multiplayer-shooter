class_name Boss
extends CharacterBody2D

enum Phase {
	## 正常状态: 追踪, 普通攻击, 冲撞, 躲子弹
	NORMAL,
	## 愤怒转换状态: 无敌, 不移动, 仅播放动画
	RAGE_TRANSLATION,
	## 愤怒状态: 追踪, 普通攻击, 冲撞, 跳起砸地 (更快的速度, 更快的CD), 躲子弹
	RAGE,
	## 害怕状态: 远离, 冲撞, 远程发射子弹, 躲子弹
	FEAR,
}

const NORMAL_SPEED: float = 150.0
const RAGE_SPEED: float = 220.0
const FEAR_SPEED: float = 180.0

const THREAT_SWITCH_THRESHOLD: float = 1.2 # 新目标仇恨必须高出 20% 才切目标
const PROXIMITY_THREAT_WEIGHT: float = 500.0



@export var attack_scene: PackedScene

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var big_check_area: Area2D = $DetectAreas/BigCheckArea
@onready var small_check_area: Area2D = $DetectAreas/SmallCheckArea
@onready var state_chart: StateChart = $StateChart

@onready var normal_attack_timer: Timer = %NormalAttackTimer
@onready var rush_timer: Timer = %RushTimer
@onready var shoot_timer: Timer = %ShootTimer
@onready var jump_timer: Timer = %JumpTimer
@onready var dodge_timer: Timer = %DodgeTimer

@onready var health_component: HealthComponent = %HealthComponent
@onready var rush_hitbox_component: HitboxComponent = %RushHitboxComponent
@onready var hurtbox_component: HurtboxComponent = %HurtboxComponent
@onready var hurtbox_shape: CollisionShape2D = $HurtboxComponent/CollisionShape2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


@onready var visual: Node2D = $Visual
@onready var animation: Node2D = $Visual/Animation

var phase: Phase = Phase.NORMAL

var big_area_players: Array = []
var small_area_players: Array = []
var big_area_bullets: Array = []

var dodge_rate: float = 0.5

var normal_attack_cooldown: float = 1.0

var special_action_cooldown: float = 2.0
var rush_cooldown: float = 8.0
var shoot_cooldown: float = 2.0
var jump_cooldown: float = 8.0


var current_speed: float = NORMAL_SPEED
var speed_offset: float = 0.0

var move_direction: Vector2 = Vector2.ZERO
var rush_direction: Vector2 = Vector2.ZERO

var target: Node2D
var is_check_flip: bool = true

# 仇恨表: Dictionary[Node2D, float]
var threat_table: Dictionary = {}
var threat_target: Node2D = null
var animation_tween: Tween

func _ready() -> void:
	animation_tween = create_tween().set_loops()
	animation_tween.tween_property(animation, "scale", Vector2(1.1, 0.9), 0.5)
	animation_tween.tween_property(animation, "scale", Vector2(0.9, 1.1), 0.5)
	animation_tween.stop()
	if multiplayer.is_server():
		normal_attack_timer.wait_time = normal_attack_cooldown
		rush_timer.wait_time = rush_cooldown
		shoot_timer.wait_time = shoot_cooldown
		jump_timer.wait_time = jump_cooldown
		health_component.max_health = 300.0 + Tools.get_game_peers_count() * 200.0
		health_component.reset()
		health_component.health_changed_with_attacker.connect(_on_health_changed)


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		if not move_direction.is_zero_approx():
			velocity = move_direction * (current_speed + speed_offset)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		# 目标更新
		if threat_target:
			target = threat_target
		if not target:
			var dis_sq: float = -1.0
			for player: Player in get_tree().get_nodes_in_group("player"):
				if dis_sq < 0:
					dis_sq = global_position.distance_squared_to(player.global_position)
					target = player
				elif dis_sq < global_position.distance_squared_to(player.global_position):
					target = player


func _process(_delta: float) -> void:
	if is_check_flip:
		check_flip()


func check_flip() -> void:
	if target:
		var flip: bool = target.global_position.x < self.global_position.x
		_rpc_flip.rpc(flip)


@rpc("authority", "call_local", "unreliable")
func _rpc_flip(flip: bool) -> void:
	visual.scale = Vector2(-1.0, 1.0) if flip else Vector2.ONE


@rpc("authority", "call_local", "reliable")
func rpc_play_animation(animation_name: StringName) -> void:
	animation_player.play(animation_name)


func _on_big_check_area_area_entered(area: Area2D) -> void:
	if multiplayer.is_server():
		if area.owner == null:
			KLogger.info("boss skip big area obj with null owner: %s" % area)
			return
		if area.owner.is_in_group("player"):
			big_area_players.append(area.owner)
		elif area.owner.is_in_group("bullet"):
			big_area_bullets.append(area.owner)
		else:
			KLogger.warn("boss skip big area obj with owner: %s" % area.owner)


func _on_big_check_area_area_exited(area: Area2D) -> void:
	if multiplayer.is_server():
		if area.owner == null:
			return
		if area.owner.is_in_group("player"):
			big_area_players.erase(area.owner)
		elif area.owner.is_in_group("bullet"):
			big_area_bullets.erase(area.owner)


func _on_small_check_area_area_entered(area: Area2D) -> void:
	if multiplayer.is_server():
		if area.owner == null:
			return
		if area.owner.is_in_group("player"):
			small_area_players.append(area.owner)


func _on_small_check_area_area_exited(area: Area2D) -> void:
	if multiplayer.is_server():
		if area.owner == null:
			return
		if area.owner.is_in_group("player"):
			small_area_players.erase(area.owner)


func _on_health_changed(max_value: float, current_value: float, damage: float, attacker: Node2D) -> void:
	if phase == Phase.RAGE_TRANSLATION or state_chart.get_expression_property("is_dead"):
		return

	# 死亡判定
	if is_zero_approx(current_value):
		KLogger.info("boss dead!!!!!")
		state_chart.set_expression_property("is_dead", true)
		state_chart.send_event("to_dying")
		return
	# 仇恨更新
	take_damage_from(damage, attacker)
	# 阶段血量阈值检查
	var hp_ratio = current_value / max_value
	if hp_ratio <= 0.25 and phase != Phase.FEAR:
		# TODO 多阶段
		KLogger.debug("boss hp ratio: %s, phase to: %s" % [hp_ratio, "FEAR"])
		# state_chart.send_event("to_fear_phase")
	elif hp_ratio <= 0.6 and phase == Phase.NORMAL:
		# TODO 多阶段
		KLogger.debug("boss hp ratio: %s, phase to: %s" % [hp_ratio, "RAGE"])
		# state_chart.send_event("to_rage_trans_phase")


# 1. 受到伤害时更新仇恨 (由伤害来源传入 attacker)
func take_damage_from(amount: float, attacker: Node2D) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return

	threat_table[attacker] = threat_table.get(attacker, 0.0) + amount
	_evaluate_primary_target()


# 2. 定期刷新与清理无效目标 (玩家断线/死亡)
func _update_threat_table(delta: float) -> void:
	var invalid_keys = []
	for p in threat_table.keys():
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			invalid_keys.append(p)
			continue

		# 距离衰减与近身基础仇恨维持
		var dist = global_position.distance_to(p.global_position)
		threat_table[p] += (PROXIMITY_THREAT_WEIGHT / (dist + 50.0)) * delta
		# 自然衰减
		threat_table[p] = max(0.0, threat_table[p] - 5.0 * delta)

	for k in invalid_keys:
		threat_table.erase(k)

	_evaluate_primary_target()


# 3. 仇恨目标仲裁 (防抖动)
func _evaluate_primary_target() -> void:
	if threat_table.is_empty():
		threat_target = null
		return

	var highest_threat_player: Node2D = null
	var max_threat: float = -1.0

	for p: Node2D in threat_table.keys():
		var t_val = threat_table[p]
		if t_val > max_threat:
			max_threat = t_val
			highest_threat_player = p

	if threat_target == null or not is_instance_valid(threat_target):
		threat_target = highest_threat_player
		return

	# 滞后阈值检查: 只有显著超越当前目标才切换
	var current_t_val = threat_table.get(threat_target, 0.0)
	if max_threat > current_t_val * THREAT_SWITCH_THRESHOLD:
		threat_target = highest_threat_player


# 计算玩家群体中心 (用于 Jump 等 AOE 技能)
func get_players_cluster_center() -> Vector2:
	var valid_players = big_area_players.filter(func(p): return is_instance_valid(p))
	if valid_players.is_empty():
		return threat_target.global_position if threat_target else global_position

	var sum_pos = Vector2.ZERO
	for p in valid_players:
		sum_pos += p.global_position
	return sum_pos / valid_players.size()
