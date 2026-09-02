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
	state = LOOK
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(&"look")
	hitbox_component.damage = init_damage
	hitbox_component.attacker = owner


func _process(_delta: float) -> void:
	match state:
		LOOK:
			if boss and boss.target:
				look_at(boss.target.global_position)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"look":
		state = ATTACK
		animation_player.play(&"attack")
	else:
		await get_tree().physics_frame
		attack_ended.emit()
		queue_free()
