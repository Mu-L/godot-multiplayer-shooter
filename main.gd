extends Node

const PLAYER = preload("uid://dgstmloeo60yy")
const ENEMY = preload("uid://pu2c45uixpy0")

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
	if is_multiplayer_authority():
		_start_spawn_enemy()


func _start_spawn_enemy() -> void:
	while true:
		if get_tree().get_node_count_in_group("enemy") < 3:
			# design size is 640 * 360
			var enemy := ENEMY.instantiate() as Node2D
			enemy.global_position = Vector2(
				100.0 + randf() * 400,
				60.0 + randf() * 250
			)
			level.add_child(enemy, true)
		await get_tree().create_timer(randf() * 5.0 + 1.0).timeout


@rpc("any_peer", "call_local", "reliable")
func _create_player() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	multiplayer_spawner.spawn({ "peer_id": sender_id })
