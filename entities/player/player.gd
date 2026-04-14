class_name Player
extends CharacterBody2D

signal died

const BULLET = preload("uid://clvtit5mibwed")
const MUZZLE_FLASH_EFFECT = preload("uid://ckgdgjh2c5e2s")
const REVIVE_HEALTH: int = 1
const BASE_MOVE_SPEED: float = 100
const BASE_FIRE_RATE: float = 0.5
const BASE_BULLET_DAMAGE: int = 1

var input_peer_id: int
var input_display_name: String

var move_vector: Vector2 = Vector2.ZERO
var is_dead: bool = false

@onready var player_input_multiplayer_synchronizer_component: PlayerInputMultiplayerSynchronizerComponent = $PlayerInputMultiplayerSynchronizerComponent
@onready var weapon_root: Node2D = %WeaponRoot
@onready var attack_timer: Timer = $AttackTimer
@onready var health_component: HealthComponent = $HealthComponent
@onready var visual_root: Node2D = $VisualRoot
@onready var weapon_animation_player: AnimationPlayer = %WeaponAnimationPlayer
@onready var attack_point: Marker2D = %AttackPoint
@onready var display_name_label: Label = %DisplayNameLabel
@onready var health_progress_bar: TextureProgressBar = %TextureProgressBar
@onready var player_info: VBoxContainer = %PlayerInfo
@onready var move_animation_player: AnimationPlayer = %MoveAnimationPlayer

func _ready() -> void:
	print("[peer %s] Set player(%s) input authroity %s" % [multiplayer.get_unique_id(), name, input_peer_id])
	player_input_multiplayer_synchronizer_component.set_multiplayer_authority(input_peer_id)
	var is_peer_authority = multiplayer.get_unique_id() == input_peer_id
	player_info.visible = not is_peer_authority
	if not is_peer_authority:
		display_name_label.text = input_display_name
	if is_multiplayer_authority():
		health_component.health_depleted.connect(_on_health_depleted)
		health_component.health_changed.connect(_on_health_changed)


func _process(delta: float) -> void:
	_update_aim_direction()
	var input := player_input_multiplayer_synchronizer_component.move_vector
	if is_zero_approx(input.length_squared()):
		move_animation_player.play("RESET")
	elif not move_animation_player.is_playing():
		move_animation_player.play("move")
	if is_multiplayer_authority():
		var target_velocity = input * _get_move_speed()
		velocity = velocity.lerp(target_velocity, 1.0 - exp(-20.0 * delta))
		move_and_slide()
		if player_input_multiplayer_synchronizer_component.is_attack_pressing:
			_try_to_attack()


func _update_aim_direction() -> void:
	var aim_vector := player_input_multiplayer_synchronizer_component.aim_vector
	visual_root.scale = Vector2.ONE if aim_vector.x >= 0 else Vector2(-1.0, 1.0)
	weapon_root.look_at(weapon_root.global_position + aim_vector)


func _get_move_speed() -> float:
	var upgrade_count := UpgradeComponent.get_peer_upgrade_count(
		input_peer_id,
		"move_speed"
	)
	return BASE_MOVE_SPEED * (1.0 + 0.1 * upgrade_count)


func _get_fire_rate() -> float:
	var upgrade_count := UpgradeComponent.get_peer_upgrade_count(
		input_peer_id,
		"fire_rate"
	)
	return BASE_FIRE_RATE * clamp(1.0 - 0.08 * upgrade_count, 0, 100)



func _get_bullet_damage() -> int:
	var upgrade_count := UpgradeComponent.get_peer_upgrade_count(
		input_peer_id,
		"damage"
	)
	return BASE_BULLET_DAMAGE + upgrade_count


func _try_to_attack() -> void:
	if not attack_timer.is_stopped():
		return
	attack_timer.wait_time = _get_fire_rate()
	attack_timer.start()
	var bullet := BULLET.instantiate() as Bullet
	bullet.global_position = attack_point.global_position
	bullet.direction = player_input_multiplayer_synchronizer_component.aim_vector
	bullet.rotation = bullet.direction.angle()
	bullet.damage = _get_bullet_damage()
	get_parent().add_child(bullet, true)
	_play_attack_effect.rpc()


@rpc("authority", "call_local", "unreliable")
func _play_attack_effect() -> void:
	if weapon_animation_player.is_playing():
		weapon_animation_player.stop()
	weapon_animation_player.play("attack")
	var effect: Node2D = MUZZLE_FLASH_EFFECT.instantiate()
	effect.global_position = attack_point.global_position
	effect.global_rotation = attack_point.global_rotation
	get_parent().add_child(effect)
	if player_input_multiplayer_synchronizer_component.is_multiplayer_authority():
		GameCamera.shake()


func _player_died() -> void:
	print("[peer %s] Player %s died!" % [multiplayer.get_unique_id(), input_peer_id])
	velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	is_dead = true
	set_player_visible.rpc(false)
	died.emit()


func revive(pos: Vector2) -> void:
	print("[peer %s] Player %s revive!" % [multiplayer.get_unique_id(), input_peer_id])
	global_position = pos
	velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_INHERIT
	health_component.reset(REVIVE_HEALTH)
	set_player_visible.rpc(true)
	is_dead = false


@rpc("authority", "call_local", "reliable")
func set_player_visible(enabled: bool) -> void:
	visible = enabled

@rpc("authority", "call_local", "reliable")
func set_player_health_bar(rate: float) -> void:
	health_progress_bar.value = rate
	if multiplayer.get_unique_id() == input_peer_id:
		GameEvents.emit_local_player_health_changed(rate)


func _on_health_depleted() -> void:
	_player_died()


func _on_health_changed(max_value: int, current_value: int) -> void:
	print("[peer %s] Player %s health change: %s / %s" % [
		multiplayer.get_unique_id(), input_peer_id, current_value, max_value
	])
	set_player_health_bar.rpc(current_value * 1.0 / max_value)
