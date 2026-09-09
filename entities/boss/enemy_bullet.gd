class_name EnemyBullet
extends Node2D

const MAX_SPEED: float = 550.0
const MIN_SPEED: float = 450.0


@export var style_textures: Array[Texture2D]
@export var sprite: Sprite2D
@export var hitbox: HitboxComponent
@export var timer: Timer

var direction: Vector2
var speed: float = MIN_SPEED
var damage: float = 2.0

var attacker: Node2D

var style_index: int = 0:
	get:
		return style_index
	set(value):
		value = clampi(value, 0, style_textures.size() - 1)
		style_index = value
		sprite.texture = style_textures[value]


func _ready() -> void:
	if multiplayer.is_server():
		timer.timeout.connect(queue_free)
		hitbox.attacker = attacker
		hitbox.damage = damage
		hitbox.is_single_hit = true
		hitbox.hit.connect(_on_hit)


func _process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_hit(_hurtbox: HurtboxComponent) -> void:
	queue_free()
