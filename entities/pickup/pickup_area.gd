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

## 旧接口使用的 pickup_type (整数枚举), 已过渡到新接口: resource
@export var pickup_type: PickupType = HEALING_POTION

## 新接口: 直接使用 CSV 中的 PickupItemResource
@export var resource: PickupItemResource = null:

	set(value):
		resource = value
		if is_inside_tree():
			_setup_appearance()

## 缓存的被动升级物品 resource, 由 _resolve_passive_resource 填充
var _passive_resource: PassiveItemResource = null

var _collected: bool = false

@onready var bubble_sprite: Sprite2D = $BubbleSprite
@onready var icon_sprite: Sprite2D = $IconSprite


func _ready() -> void:
	add_to_group("pickup")
	_setup_appearance()
	_play_idle_animation()
	if is_multiplayer_authority():
		# player 的 CharacterBody2D 在 layer_4, 命中 body_entered (而非 area_entered)
		body_entered.connect(_on_body_entered)


func _resolve_passive_resource() -> PassiveItemResource:
	if _passive_resource != null:
		return _passive_resource
	if resource == null or resource.effect_type != PASSIVE_EFFECT_TYPE:
		return null
	_passive_resource = CSVResourceCache.get_passive(resource.effect_params)
	return _passive_resource


func _setup_appearance() -> void:
	# 优先使用 resource (新接口), 否则回退到旧枚举接口
	if resource != null:
		var passive_res := _resolve_passive_resource()
		if passive_res != null:
			# passive_upgrade 类型: 使用对应被动物品的 icon
			icon_sprite.texture = passive_res.icon
		elif resource.icon != null:
			# 普通类型: 使用 csv 中配置的 icon
			icon_sprite.texture = resource.icon
		return
	# 旧接口回退 (仅作兼容)
	match pickup_type:
		HEALING_POTION:
			icon_sprite.texture = HEALING_POTION_TEX
		MEDKIT:
			icon_sprite.texture = MEDKIT_TEX
		UPGRADE:
			icon_sprite.texture = UPGRADE_TEX


func _play_idle_animation() -> void:
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
	rpc("_sync_collect")
	_apply_effect(player)
	# 延迟一帧, 让同步 RPC 先发送
	await get_tree().process_frame
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_collect() -> void:
	# 播放消失动画 (缩放消失), bubble 仍可见但 icon 消失
	if is_multiplayer_authority():
		return
	var tween := create_tween()
	tween.tween_property(bubble_sprite, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _apply_effect(player: Player) -> void:
	if not is_multiplayer_authority():
		return
	# 优先使用 resource (新接口), 否则回退到旧枚举
	if resource != null:
		if resource.effect_type == PASSIVE_EFFECT_TYPE:
			_apply_passive_upgrade(player)
		elif resource.id == "healing_potion":
			player.healing(int(resource.effect_params))
		elif resource.id == "medkit":
			player.healing(999)
		return
	# 旧接口回退
	match pickup_type:
		HEALING_POTION:
			player.healing(1)
		MEDKIT:
			player.healing(999)
		UPGRADE:
			_apply_random_upgrade(player)


func _apply_passive_upgrade(player: Player) -> void:
	var passive_res := _resolve_passive_resource()
	if passive_res == null:
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
