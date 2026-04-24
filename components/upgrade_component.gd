class_name UpgradeComponent
extends Node

signal upgrade_finished

static var instance: UpgradeComponent

@export var upgrade_options_ui: UpgradeOptionsUI
@export var available_upgrade_resources: Array[UpgradeResource]

var resources_id_dict: Dictionary[String, UpgradeResource] = {}
var avaiable_peer_resources: Dictionary[int, Array] = {}
var peer_selected_upgrades: Dictionary[int, Dictionary] = {}


static func get_peer_upgrade_count(peer_id: int, resource_id: String) -> int:
	if not is_instance_valid(instance):
		return 0
	if peer_id not in instance.peer_selected_upgrades:
		return 0
	var selected_upgrades: Dictionary = instance.peer_selected_upgrades[peer_id]
	return selected_upgrades.get(resource_id, 0)


func _ready() -> void:
	instance = self
	for res in available_upgrade_resources:
		resources_id_dict[res.id] = res
	upgrade_options_ui.upgrade_selected.connect(_on_upgrade_option_selected)
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func generate_options() -> void:
	if not is_multiplayer_authority():
		return
	var all_peers := Tools.get_game_peers()
	avaiable_peer_resources.clear()
	for peer in all_peers:
		var copy_resources := Array(available_upgrade_resources)
		copy_resources.shuffle()
		var resources = copy_resources.slice(0, 3)
		avaiable_peer_resources[peer] = resources
		var resource_ids = resources.map(func(res: UpgradeResource): return res.id)
		show_upgrade_options.rpc_id(peer, resource_ids)


func _check_upgrade_finished() -> void:
	if avaiable_peer_resources.is_empty():
		upgrade_finished.emit()


@rpc("authority", "call_local", "reliable")
func show_upgrade_options(resource_ids: Array) -> void:
	var resources := resource_ids.map(func(res_id: String): return resources_id_dict[res_id])
	upgrade_options_ui.show_upgrade_options(resources)


@rpc("any_peer", "call_local", "reliable")
func select_upgrade_option(index: int) -> void:
	if not is_multiplayer_authority():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not peer_id in avaiable_peer_resources:
		return
	var resources := avaiable_peer_resources[peer_id]
	if index < 0 or index >= resources.size():
		return
	avaiable_peer_resources.erase(peer_id)
	var selected_resource: UpgradeResource = resources[index]
	var peer_upgrade_count_dic: Dictionary = peer_selected_upgrades.get_or_add(peer_id, {})
	var count = peer_upgrade_count_dic.get_or_add(selected_resource.id, 0)
	peer_upgrade_count_dic[selected_resource.id] = count + 1
	print("[peer %s] peer %s selected upgrade option id: %s" % [
		multiplayer.get_unique_id(),
		peer_id,
		selected_resource.id
	])
	_check_upgrade_finished()


func _on_upgrade_option_selected(index: int) -> void:
	# 由各peer本地触发, peer id需要传递给服务器
	select_upgrade_option.rpc_id(1, index)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in avaiable_peer_resources:
		avaiable_peer_resources.erase(peer_id)
		_check_upgrade_finished()
