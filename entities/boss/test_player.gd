extends CharacterBody2D

var speed: float = 120.0
var mouse_point: Vector2


func _physics_process(_delta: float) -> void:
	mouse_point = get_global_mouse_position()
	if global_position.distance_squared_to(mouse_point) > 100.0:
		velocity = global_position.direction_to(mouse_point) * speed
		move_and_slide()
