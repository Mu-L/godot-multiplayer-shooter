class_name PickupArea
extends Area2D

enum PickupType { HEALING_POTION, MEDKIT, UPGRADE }

const HEALING_POTION := PickupType.HEALING_POTION
const MEDKIT := PickupType.MEDKIT
const UPGRADE := PickupType.UPGRADE

const HEALING_POTION_TEX := preload("res://assets/healing_potion.tres")
const MEDKIT_TEX := preload("res://assets/medkit.tres")
const UPGRADE_TEX := preload("res://assets/basic_damage_up.tres")

@export var pickup_type: PickupType = HEALING_POTION

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


func _setup_appearance() -> void:
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
	match pickup_type:
		HEALING_POTION:
			player.healing(1)
		MEDKIT:
			player.healing(999)
		UPGRADE:
			_apply_random_upgrade(player)


func _apply_random_upgrade(player: Player) -> void:
	if not is_multiplayer_authority():
		return
	UpgradeComponent.instance.apply_free_upgrade(player.input_peer_id)
