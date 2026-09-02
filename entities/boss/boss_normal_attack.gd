class_name BossNormalAttack
extends Node2D


signal attack_ended

enum {
	LOOK,
	ATTACK,
}

@export var boss: Boss

var init_damage: float = 1.0
var state: int = LOOK


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var collision_shape_2d: CollisionShape2D = $HitboxComponent/CollisionShape2D


func _ready() -> void:
	animation_player.play(&"look")
	if multiplayer.is_server():
		state = LOOK
		animation_player.animation_finished.connect(_on_animation_finished)
		hitbox_component.damage = init_damage
		hitbox_component.attacker = owner


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		match state:
			LOOK:
				if boss and boss.target:
					rpc_look_at.rpc(boss.target.global_position)


@rpc("authority", "call_local", "unreliable")
func rpc_look_at(pos: Vector2) -> void:
	look_at(pos)


@rpc("authority", "call_local", "reliable")
func rpc_play_animation(anim_name: StringName) -> void:
	animation_player.play(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"look":
		state = ATTACK
		rpc_play_animation.rpc(&"attack")
	else:
		await get_tree().physics_frame
		attack_ended.emit()
		queue_free()
