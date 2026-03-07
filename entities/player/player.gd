extends CharacterBody2D

var input_peer_id : int
var move_vector: Vector2 = Vector2.ZERO
var move_speed: float = 100.0

@onready var player_input_multiplayer_synchronizer_component: PlayerInputMultiplayerSynchronizerComponent = $PlayerInputMultiplayerSynchronizerComponent

func _ready() -> void:
	print("[peer %s] Set player(%s) input authroity %s" % [multiplayer.get_unique_id(), name, input_peer_id])
	player_input_multiplayer_synchronizer_component.set_multiplayer_authority(input_peer_id)


func _process(_delta: float) -> void:
	var input := player_input_multiplayer_synchronizer_component.move_vector
	velocity = input * move_speed
	move_and_slide()
