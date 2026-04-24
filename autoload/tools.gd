extends Node


func is_headless_server() -> bool:
	if OS.has_feature("dedicated_server") or\
		DisplayServer.get_name() == "headless" or\
		"--server" in OS.get_cmdline_user_args():
			return true
	return false


func get_game_peers() -> Array:
	var game_peers := multiplayer.get_peers()
	if not Tools.is_headless_server():
		game_peers.append(1)
	return game_peers


func get_game_peers_count() -> int:
	return get_game_peers().size()
