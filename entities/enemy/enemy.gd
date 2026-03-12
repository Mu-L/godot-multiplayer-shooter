extends CharacterBody2D

var current_health : int = 5

@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	if is_multiplayer_authority():
		area_2d.area_entered.connect(_on_area_entered)


func _handle_hit() -> void:
	current_health -= 1
	if current_health <= 0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.owner is Bullet:
		return
	var bullet := area.owner as Bullet
	bullet.register_collision()
	_handle_hit()
