class_name PickupArea
extends Area2D

## 可拾取物品在 res://config/pickup_item_config.csv 中统一配置
## effect_type = "passive_upgrade" 时表示被动升级物品, effect_params 是 passive_item 的 id
## 若 effect_type 是 "passive_upgrade", 其 icon 从 passive_item_config.csv 读取

const PASSIVE_EFFECT_TYPE := "passive_upgrade"

## 目前仍保留兼容旧的整数枚举接口 (给 EnemySpawnComponent._roll_pick_type 使用)
enum PickupType { HEALING_POTION, MEDKIT, UPGRADE }

const HEALING_POTION := PickupType.HEALING_POTION
const MEDKIT := PickupType.MEDKIT
const UPGRADE := PickupType.UPGRADE

const HEALING_POTION_TEX := preload("res://assets/healing_potion.tres")
const MEDKIT_TEX := preload("res://assets/medkit.tres")
const UPGRADE_TEX := preload("res://assets/basic_damage_up.tres")

const MAX_LIVE_TIME: float = 10.0
const FLASH_LIVE_TIME: float = 7.0

## 新接口: 直接使用 CSV 中的 PickupItemResource
@export var resource: PickupItemResource = null:
	set(value):
		resource = value
		if is_inside_tree():
			_setup_appearance()

## 网络同步用的 PickupItemResource id 字符串, 由 authority 在 spawn 时写入;
## MultiplayerSynchronizer 同步该字段, 客户端收到后填充 resource 并更新图标;
## (必须在 @export var resource 之后声明, 避免 setter 竞态)
@export var resource_id: String = "":
	set(value):
		resource_id = value
		# 客户端路径: 从 value 反查 CSVResourceCache, 重建 resource 并更新图标
		# is_inside_tree 必须放前面 — is_multiplayer_authority 不在树内调用会报错;
		# authority 端走 resource.setter + _ready()._setup_appearance(), 无需这里重复刷新
		if is_inside_tree() and not is_multiplayer_authority():
			resource = CSVResourceCache.get_pickup(value)
			if not resource:
				push_warning("[PickupArea] client: unknown pickup id: %s" % value)
			_setup_appearance()


## 弹出动画位移
var spawn_pos_offset: Vector2 = Vector2.ZERO

var show_bubble: bool = true

## 缓存的被动升级物品 resource, 由 _resolve_passive_resource 填充
var _passive_resource: PassiveItemResource = null

var _collected: bool = false

var live_time: float = 0.0

@onready var bubble_sprite: Sprite2D = $BubbleSprite
@onready var icon_sprite: Sprite2D = $IconSprite


func _ready() -> void:
	add_to_group("pickup")
	if is_multiplayer_authority():
		# player 的 CharacterBody2D 在 layer_4, 命中 body_entered (而非 area_entered)
		body_entered.connect(_on_body_entered)
	await get_tree().process_frame
	_setup_appearance()
	_play_spawn_animation()


func _process(delta: float) -> void:
	if live_time < FLASH_LIVE_TIME and live_time + delta >= FLASH_LIVE_TIME:
		_play_flash_animation()
	if live_time < MAX_LIVE_TIME and live_time + delta >= MAX_LIVE_TIME:
		if multiplayer.is_server():
			queue_free()
	live_time += delta


func _play_flash_animation() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(icon_sprite, "self_modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property(bubble_sprite, "self_modulate", Color.TRANSPARENT, 0.3)
	tween.tween_property(icon_sprite, "self_modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(bubble_sprite, "self_modulate", Color.WHITE, 0.3)


func _resolve_passive_resource() -> PassiveItemResource:
	if _passive_resource:
		return _passive_resource
	if not resource or resource.effect_type != PASSIVE_EFFECT_TYPE:
		return null
	_passive_resource = CSVResourceCache.get_passive(resource.effect_params[0])
	return _passive_resource


func _setup_appearance() -> void:
	if bubble_sprite:
		bubble_sprite.visible = show_bubble
	if resource:
		var passive_res := _resolve_passive_resource()
		if is_instance_valid(icon_sprite):
			if passive_res:
				# passive_upgrade 类型: 使用对应被动物品的 icon
				icon_sprite.texture = passive_res.icon
			elif resource.icon:
				# 普通类型: 使用 csv 中配置的 icon
				icon_sprite.texture = resource.icon


func _play_spawn_animation() -> void:
	# 插值驱动二次贝塞尔曲线
	var tween: Tween = create_tween().set_parallel(true)

	# 计算弧线控制点
	var target_pos: Vector2 = global_position + spawn_pos_offset
	var start_pos: Vector2 = global_position
	var random_arc_offset: Vector2 = Vector2(randf_range(-20.0, 20.0), -randf_range(30.0, 60.0))
	var fly_time: float = 0.5
	# P = (1-t)^2 * P0 + 2t(1-t) * P1 + t^2 * P2
	tween.tween_method(
		func(t: float) -> void:
			var current_target_pos: Vector2 = target_pos
			var control_pt: Vector2 = (start_pos + current_target_pos) * 0.5 + random_arc_offset
			var q0: Vector2 = start_pos.lerp(control_pt, t)
			var q1: Vector2 = control_pt.lerp(current_target_pos, t)
			global_position = q0.lerp(q1, t),
		0.0, 1.0, fly_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 放大淡入
	tween.tween_property(self, "scale", Vector2.ONE, fly_time).from(Vector2.ZERO)

	# 动画完成后回调
	tween.chain().tween_callback(func() -> void:
		_play_idle_animation()
	)


func _play_idle_animation() -> void:
	if not show_bubble:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bubble_sprite, "position:y", -3.0, 0.75)
	tween.tween_property(bubble_sprite, "position:y", 0.0, 0.75)


func _on_body_entered(body: Node) -> void:
	if not is_multiplayer_authority() or _collected:
		return
	if not body.is_in_group("player") or not (body is Player):
		return
	if body.is_dead:
		return
	_collect(body)


func _collect(player: Player) -> void:
	_collected = true
	# 先广播同步给所有客户端 (包括自己), 让客户端也播放消失动画
	_sync_collect.rpc()
	_apply_effect(player)
	# 延迟一帧, 让同步 RPC 先发送完毕
	await get_tree().process_frame
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_collect() -> void:
	# 仅在非 authority 端播放消失动画 (authority 端已经在 _collect 后 queue_free)
	if is_multiplayer_authority():
		return
	# 客户端: 播放拾取消失动画
	_play_collected_animation()


func _play_collected_animation() -> void:
	var tween := create_tween()
	tween.tween_property(bubble_sprite, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _apply_effect(player: Player) -> void:
	if not is_multiplayer_authority():
		return
	if resource:
		if resource.effect_type == PASSIVE_EFFECT_TYPE:
			_apply_passive_upgrade(player)
		elif resource.id == "healing_potion":
			player.healing(randf_range(resource.effect_params[0], resource.effect_params[1]))
		elif resource.id == "medkit":
			player.healing(resource.effect_params[0])


func _apply_passive_upgrade(player: Player) -> void:
	var passive_res := _resolve_passive_resource()
	if not passive_res:
		push_warning("[PickupArea] passive_upgrade 未能解析: %s" % resource.effect_params)
		return
	UpgradeComponent.instance.apply_specific_upgrade(player.input_peer_id, passive_res.id)
	# 被动升级拾取后播放过关升级的音效提示
	if multiplayer.get_unique_id() == player.input_peer_id:
		SoundManager.play_select()


func _apply_random_upgrade(player: Player) -> void:
	if not is_multiplayer_authority():
		return
	UpgradeComponent.instance.apply_free_upgrade(player.input_peer_id)
