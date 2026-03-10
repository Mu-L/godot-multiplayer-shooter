class_name Bullet
extends Node2D


const SPEED : float = 600.0

var direction : Vector2

@onready var timer: Timer = $Timer


func _ready() -> void:
	if is_multiplayer_authority():
		timer.process_mode = Node.PROCESS_MODE_INHERIT
		timer.timeout.connect(func():
			queue_free()
		)


func _process(delta: float) -> void:
	global_position += direction * SPEED * delta
