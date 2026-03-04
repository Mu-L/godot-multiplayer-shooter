extends Control

const PORT : int = 34560

@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_host_pressed() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	server_peer.create_server(PORT)
	multiplayer.multiplayer_peer = server_peer


func _on_join_pressed() -> void:
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = client_peer


func _on_peer_connected(id: int) -> void:
	print("my peer [%s] connected: %s" % [multiplayer.get_unique_id(), id])
