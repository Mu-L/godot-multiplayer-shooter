class_name DodgeShield
extends Area2D

const FINAL_SCALE: float = 4.0

@export var collision_shape: CollisionShape2D
@export var sprite: Sprite2D

var init_max_time: float = 1.0
var cur_time: float = 0.0

func _ready() -> void:
	if multiplayer.is_server():
		area_entered.connect(_on_area_entered)
	var origin_color: Color = sprite.modulate
	var transparent_color: Color = Color(origin_color, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * FINAL_SCALE, init_max_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", transparent_color, init_max_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_area_entered(area: Area2D) -> void:
	if not area is HitboxComponent:
		return
	var hitbox := area as HitboxComponent
	if hitbox.owner is Bullet:
		# TODO 音效
		hitbox.owner.queue_free()
