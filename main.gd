extends Node

const PLAYER = preload("uid://dgstmloeo60yy")

@onready var level: Node2D = $Level
@onready var multiplayer_spawner: MultiplayerSpawner = %MultiplayerSpawner

func _ready() -> void:
	multiplayer_spawner.spawn_function = func(data):
		print("[peer %s] Spawn player: %s" % [multiplayer.get_unique_id(), data.peer_id])
		var player = PLAYER.instantiate()
		player.name = "Player%s" % [data.peer_id]
		player.input_peer_id = data.peer_id
		return player
	_create_player.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _create_player() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	multiplayer_spawner.spawn({ "peer_id": sender_id })
