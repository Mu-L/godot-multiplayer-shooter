class_name PlayerInputMultiplayerSynchronizerComponent
extends MultiplayerSynchronizer

var move_vector : Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
