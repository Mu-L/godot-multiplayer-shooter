class_name UpgradeComponent
extends Node

signal upgrade_finished

const ITEM_ID_MOVE_SPEED_UP: String = "move_speed_up"
const ITEM_ID_BASIC_DAMAGE_UP: String = "basic_damage_up"
const ITEM_ID_ATTACK_SPEED_UP: String = "attack_speed_up"
const ITEM_ID_HEALTH_LIMIT_UP: String = "health_limit_up"
const ITEM_ID_BULLET_SPLIT: String = "bullet_split"
const ITEM_ID_DEFENCE_UP: String = "defence_up"


static var instance: UpgradeComponent

@export var upgrade_options_ui: UpgradeOptionsUI

var resources_id_dict: Dictionary[String, PassiveItemResource] = {}
var avaiable_peer_resources: Dictionary[int, Array] = {}
var peer_selected_passives: Dictionary[int, Dictionary] = {}


static func get_peer_upgrade_count(peer_id: int, resource_id: String) -> int:
	return get_peer_passive_count(peer_id, resource_id)


static func get_peer_passive_count(peer_id: int, passive_id: String) -> int:
	if not is_instance_valid(instance):
		return 0
	if peer_id not in instance.peer_selected_passives:
		return 0
	var selected_passives: Dictionary = instance.peer_selected_passives[peer_id]
	return selected_passives.get(passive_id, 0)


static func calc_health_limit(peer_id: int, base_value: float) -> float:
	if not is_instance_valid(instance):
		return base_value
	var count: int = get_peer_passive_count(peer_id, ITEM_ID_HEALTH_LIMIT_UP)
	var res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_HEALTH_LIMIT_UP)
	var param: float = 1.0
	if res and not res.effect_params.is_empty():
		param = count * res.effect_params[0]
	return base_value + param


static func calc_defence(peer_id: int) -> float:
	if not is_instance_valid(instance):
		return 1.0
	var count: int = get_peer_passive_count(peer_id, ITEM_ID_DEFENCE_UP)
	var res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_DEFENCE_UP)
	var param: float = 1.0 # 实际承受伤害的比例
	if res and not res.effect_params.is_empty():
		param = res.effect_params[0] ** count
	return param


static func calc_move_speed(peer_id: int, base_speed: float) -> float:
	if not is_instance_valid(instance):
		return base_speed
	var count: int = get_peer_passive_count(peer_id, ITEM_ID_MOVE_SPEED_UP)
	var res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_MOVE_SPEED_UP)
	var param: float = 0.1
	if res and not res.effect_params.is_empty():
		param = res.effect_params[0]
	else:
		KLogger.error("wrong csv params for item %s" % ITEM_ID_MOVE_SPEED_UP)
	return base_speed * (1.0 + param * count)


static func calc_fire_rate(peer_id: int, base_rate: float) -> float:
	if not is_instance_valid(instance):
		return base_rate
	var count: int = get_peer_passive_count(peer_id, ITEM_ID_ATTACK_SPEED_UP)
	var res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_ATTACK_SPEED_UP)
	var param: float = 0.1
	if res and not res.effect_params.is_empty():
		param = res.effect_params[0]
	else:
		KLogger.error("wrong csv params for item %s" % ITEM_ID_ATTACK_SPEED_UP)
	return base_rate * clampf(1.0 - param * count, 0.001, 10.0)


static func calc_bullet_damage(peer_id: int, base_damage: float) -> float:
	if not is_instance_valid(instance):
		return base_damage
	# 先计算基础攻击加成
	var damage_up_count: int = get_peer_passive_count(peer_id, ITEM_ID_BASIC_DAMAGE_UP)
	var damage_up_res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_BASIC_DAMAGE_UP)
	var damage_param: float = 1.0
	if damage_up_res and not damage_up_res.effect_params.is_empty():
		damage_param = damage_up_res.effect_params[0]
	base_damage += damage_up_count * damage_param
	# 再计算弹道分裂减伤
	var split_item_count: int = get_peer_passive_count(peer_id, ITEM_ID_BULLET_SPLIT)
	var split_item_res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_BULLET_SPLIT)
	var split_param: float = 0.7
	if split_item_res and split_item_res.effect_params.size() > 1:
		split_param = split_item_res.effect_params[1]
	base_damage *= (split_param ** split_item_count)
	return base_damage


static func calc_bullet_count(peer_id: int) -> int:
	if not is_instance_valid(instance):
		return 1
	var item_count: int = get_peer_passive_count(peer_id, ITEM_ID_BULLET_SPLIT)
	var item_res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_BULLET_SPLIT)
	var item_param: int = 2
	if item_res and item_res.effect_params.size() > 0:
		item_param = item_res.effect_params[0]
	return 1 + item_param * item_count


func _ready() -> void:
	instance = self
	_refresh_passive_resources()
	upgrade_options_ui.upgrade_selected.connect(_on_upgrade_option_selected)
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func generate_options() -> void:
	if not is_multiplayer_authority():
		return
	if resources_id_dict.is_empty():
		push_warning("No passive item resources loaded for upgrade options.")
		upgrade_finished.emit()
		return
	var all_peers := Tools.get_game_peers()
	avaiable_peer_resources.clear()
	for peer in all_peers:
		var copy_resources := Array(resources_id_dict.values())
		copy_resources.shuffle()
		var resources := copy_resources.slice(0, min(3, copy_resources.size()))
		avaiable_peer_resources[peer] = resources
		var resource_ids := resources.map(func(res: PassiveItemResource) -> String: return res.id)
		show_upgrade_options.rpc_id(peer, resource_ids)


func _check_upgrade_finished() -> void:
	if avaiable_peer_resources.is_empty():
		upgrade_finished.emit()


@rpc("authority", "call_local", "reliable")
func show_upgrade_options(resource_ids: Array) -> void:
	var resources := resource_ids.map(func(res_id: String) -> PassiveItemResource: return resources_id_dict[res_id])
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
	var selected_resource: PassiveItemResource = resources[index]
	var peer_passive_count_dic: Dictionary = peer_selected_passives.get_or_add(peer_id, {})
	var count: int = peer_passive_count_dic.get_or_add(selected_resource.id, 0)
	peer_passive_count_dic[selected_resource.id] = count + 1
	print("[peer %s] peer %s selected passive item id: %s, total count: %s" % [
		multiplayer.get_unique_id(),
		peer_id,
		selected_resource.id,
		count + 1,
	])
	if selected_resource.id == ITEM_ID_DEFENCE_UP:
		_on_defence_upgraded(peer_id)
	elif selected_resource.id == ITEM_ID_HEALTH_LIMIT_UP:
		_on_health_limit_upgraded(peer_id)
	_check_upgrade_finished()


## 防御升级后通知对应 peer 更新 HUD 减伤百分比
func _on_defence_upgraded(peer_id: int) -> void:
	var percent: float = snappedf((1.0 - calc_defence(peer_id)) * 100.0, 1.0)
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Player and p.input_peer_id == peer_id:
			p._notify_defense_changed.rpc_id(peer_id, percent)
			return


## 血量上限升级后通知对应 player 刷新属性
func _on_health_limit_upgraded(peer_id: int) -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Player and p.input_peer_id == peer_id:
			p._refresh_health_limit()
			return


func _on_upgrade_option_selected(index: int) -> void:
	# 由各peer本地触发, peer id需要传递给服务器
	select_upgrade_option.rpc_id(1, index)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in avaiable_peer_resources:
		avaiable_peer_resources.erase(peer_id)
		_check_upgrade_finished()
	peer_selected_passives.erase(peer_id)


func _refresh_passive_resources() -> void:
	resources_id_dict.clear()
	for res: PassiveItemResource in CSVResourceCache.get_all_passives():
		resources_id_dict[res.id] = res


## 获取本地化文本(在 static 上下文中替代 tr()).
static func _tr(msgid: String) -> String:
	if not is_instance_valid(instance):
		return TranslationServer.translate(msgid)
	return instance.tr(msgid)


## 根据 effect_params 代入翻译模板生成最终描述.
## 翻译文件中的模板使用 {0} {1} ... 占位符,此处用 effect_params 的实际数值代入.
static func formatted_description(resource: PassiveItemResource) -> String:
	if resource == null:
		return ""
	var res: PassiveItemResource = resource
	if is_instance_valid(instance):
		var cached: PassiveItemResource = instance.resources_id_dict.get(resource.id)
		if cached != null:
			res = cached
	var template: String = _tr(res.description_key)
	var display_params: Array = []
	for param in res.effect_params:
		display_params.append(_format_effect_param(param))
	for i in range(display_params.size()):
		template = template.replace("{%d}" % i, str(display_params[i]))
	return template


static func _format_effect_param(param) -> String:
	match typeof(param):
		TYPE_FLOAT:
			# 0~1 范围内的小数视为比例,显示为百分比 (如 0.1 -> "10%", 0.8 -> "80%")
			# 排除整数值的浮点数 (如 1.0)
			if param > 0.0 and param < 1.0 and not is_equal_approx(param, snappedf(param, 1.0)):
				return "%.0f%%" % (param * 100.0)
			return _format_number(param)
		TYPE_INT:
			return str(param)
		_:
			return str(param)


static func _format_number(value: float) -> String:
	if is_equal_approx(value, snappedf(value, 1.0)):
		return str(int(value))
	# 最多保留 2 位小数,去掉末尾无意义的 0
	return ("%.2f" % value).rstrip("0").rstrip(".")


## 免费升级: 奖励关拾取物触发. 不走全玩家同步流程, 单人次直接应用 (instance method)
func apply_free_upgrade(peer_id: int) -> void:
	if resources_id_dict.is_empty():
		return
	var all_passives := resources_id_dict.keys()
	var chosen: String = all_passives[randi() % all_passives.size()]
	var peer_passive_count_dic: Dictionary = peer_selected_passives.get_or_add(peer_id, {})
	var count: int = peer_passive_count_dic.get_or_add(chosen, 0)
	peer_passive_count_dic[chosen] = count + 1
	KLogger.info("[FreeUpgrade] peer %s got %s (count: %s)" % [peer_id, chosen, count + 1])
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Player and p.input_peer_id == peer_id:
			p._on_free_upgrade_applied(chosen)
			return
