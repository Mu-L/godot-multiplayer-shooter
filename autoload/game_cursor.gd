extends CanvasLayer


@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	sprite_2d.global_position = sprite_2d.get_global_mouse_position()
