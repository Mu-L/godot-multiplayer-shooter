extends Node

signal enemy_died
signal local_player_health_changed(rate)
signal local_player_defense_changed(percent)
signal player_look_changed(peer_id: int, player_look_index: int)
 ## 本地玩家的被动道具持有数发生变化 (客户端缓存同步后触发)
signal local_player_passives_changed(passives: Dictionary)


func emit_enemy_died() -> void:
	enemy_died.emit()


func emit_local_player_health_changed(rate: float) -> void:
	local_player_health_changed.emit(rate)


func emit_local_player_defense_changed(percent: float) -> void:
	local_player_defense_changed.emit(percent)


func emit_player_look_changed(peer_id: int, player_look_index: int):
	player_look_changed.emit(peer_id, player_look_index)


func emit_local_player_passives_changed(passives: Dictionary) -> void:
	local_player_passives_changed.emit(passives)
