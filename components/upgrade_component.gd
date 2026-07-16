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

## 客户端缓存的所有 peer 被动持有数 (通过 _notify_passive_changed RPC 同步)
var client_passive_counts: Dictionary = {} # {peer_id: {passive_id: count}}
 ## 后续其他需求(如观察队友 build)的基础数据


static func get_peer_upgrade_count(peer_id: int, resource_id: String) -> int:
	return get_peer_passive_count(peer_id, resource_id)


static func get_peer_passive_count(peer_id: int, passive_id: String) -> int:
	if not is_instance_valid(instance):
		return 0
	if instance.is_multiplayer_authority():
		# 权威端: 从权威字典读取
		if peer_id not in instance.peer_selected_passives:
			return 0
		var selected_passives: Dictionary = instance.peer_selected_passives[peer_id]
		return selected_passives.get(passive_id, 0)
	else:
		# 客户端: 从同步缓存读取 (由 _notify_passive_changed RPC 填充)
		var client_dic: Dictionary = instance.client_passive_counts.get(peer_id, {})
		return client_dic.get(passive_id, 0)


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


## 计算子弹伤害的逐段拆解, 供属性面板多段显示.
## 返回字典: final(最终伤害), base(原始基础值), bonus(基础伤害加成,绿色),
## pre_split(加成后/减伤前), split_factor(分裂总系数,红色), is_split_active(是否发生分裂减伤)
static func calc_bullet_damage_breakdown(peer_id: int, base_damage: float) -> Dictionary:
	var res := {
		"final": base_damage,
		"base": base_damage,
		"bonus": 0.0,
		"pre_split": base_damage,
		"split_factor": 1.0,
		"is_split_active": false,
	}
	if not is_instance_valid(instance):
		return res
	# 基础攻击加成
	var damage_up_count: int = get_peer_passive_count(peer_id, ITEM_ID_BASIC_DAMAGE_UP)
	var damage_up_res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_BASIC_DAMAGE_UP)
	var damage_param: float = 1.0
	if damage_up_res and not damage_up_res.effect_params.is_empty():
		damage_param = damage_up_res.effect_params[0]
	var bonus: float = damage_up_count * damage_param
	var pre_split: float = base_damage + bonus
	# 弹道分裂减伤
	var split_item_count: int = get_peer_passive_count(peer_id, ITEM_ID_BULLET_SPLIT)
	var split_item_res: PassiveItemResource = instance.resources_id_dict.get(ITEM_ID_BULLET_SPLIT)
	var split_param: float = 0.7
	if split_item_res and split_item_res.effect_params.size() > 1:
		split_param = split_item_res.effect_params[1]
	var factor: float = split_param ** split_item_count
	res["final"] = pre_split * factor
	res["base"] = base_damage
	res["bonus"] = bonus
	res["pre_split"] = pre_split
	res["split_factor"] = factor
	res["is_split_active"] = split_item_count > 0
	return res


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
	var all_peers: Array = Tools.get_game_peers()
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
	var selected_name := tr(selected_resource.name_key)
	KLogger.info("[UpgradeLog] peer %s selected upgrade: %s" % [peer_id, selected_name])
	_log_peer_upgrades(peer_id, peer_selected_passives)
	if selected_resource.id == ITEM_ID_DEFENCE_UP:
		_on_defence_upgraded(peer_id)
	elif selected_resource.id == ITEM_ID_HEALTH_LIMIT_UP:
		_on_health_limit_upgraded(peer_id)
	# 广播被动数量变化给所有 peer (客户端缓存)
	_notify_passive_changed.rpc(peer_id, selected_resource.id, count + 1)
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


## 打印玩家当前拥有的完整升级清单 (authority 端).
## 格式: [升级名称1x升级数量1, 升级名称2x升级数量2, ...]
static func _log_peer_upgrades(peer_id: int, _peer_selected_passives: Dictionary) -> void:
	if not is_instance_valid(instance):
		return
	var passive_count_dic: Dictionary = _peer_selected_passives.get(peer_id, {})
	if passive_count_dic.is_empty():
		KLogger.info("[UpgradeLog] peer %s has no upgrades" % peer_id)
		return
	var items: Array[String] = []
	for passive_id in passive_count_dic:
		var res: PassiveItemResource = instance.resources_id_dict.get(passive_id as String)
		var res_name: String = instance.tr(res.name_key) if res else passive_id
		items.append("%sx%s" % [res_name, passive_count_dic[passive_id]])
	KLogger.info("[UpgradeLog] peer %s got upgrades: [%s]" % [peer_id, ", ".join(items)])


func _refresh_passive_resources() -> void:
	resources_id_dict.clear()
	for res: PassiveItemResource in CSVResourceCache.get_all_passives():
		resources_id_dict[res.id] = res


## 单级被动物品效果描述.
## 使用 PASSIVE_ITEM_*_DESCRIPTION 翻译模板,占位符 {0} {1} 直接代入 effect_params 原始数值(保留"比例"还是"数值"语义由 CSV 决定).
static func formatted_description(resource: PassiveItemResource) -> String:
	if resource == null:
		return ""
	var res: PassiveItemResource = resource
	if is_instance_valid(instance):
		var cached: PassiveItemResource = instance.resources_id_dict.get(resource.id)
		if cached != null:
			res = cached
	var template: String = instance.tr(res.description_key)
	# 用 replace 着色,避免 % 运算符把占位符里的裸 %" 当成格式化 token 解析.
	for i in range(res.effect_params.size()):
		template = template.replace("{%d}" % i, _format_value(res.effect_params[i]))
	return template


## 叠加后被动物品效果描述 (count >= 2 时由调用方决定是否回退到单级描述).
## 每种道具的数值语义各不相同(整数累加 / 比例累加 / 累乘 / 混合),因此按 match case 各自独立格式化,
## 再通过独立的翻译模板 PASSIVE_STACKED_* 输出供外部本地化,不做统一模板.
static func formatted_description_stacked(resource: PassiveItemResource, count: int) -> String:
	if resource == null or count <= 0:
		return ""
	if count == 1:
		# 叠加数 = 1 时走单级描述,与"叠加效果"区段隐藏逻辑一致.
		return formatted_description(resource)
	var res: PassiveItemResource = resource
	if is_instance_valid(instance):
		var cached: PassiveItemResource = instance.resources_id_dict.get(resource.id)
		if cached != null:
			res = cached
	match res.id:
		ITEM_ID_BASIC_DAMAGE_UP:
			# effect_params[0] = 1.0, 每级 +1 基础伤害 (整数加法).
			var total: int = int(float(res.effect_params[0]) * count)
			return instance.tr("PASSIVE_STACKED_BASIC_DAMAGE_UP").format([total], "{_}")
		ITEM_ID_HEALTH_LIMIT_UP:
			# effect_params[0] = 1.0, 每级 +1 血量上限 (整数加法).
			var total: int = int(float(res.effect_params[0]) * count)
			return instance.tr("PASSIVE_STACKED_HEALTH_LIMIT_UP").format([total], "{_}")
		ITEM_ID_ATTACK_SPEED_UP:
			# effect_params[0] = 0.1, 每级 +10% 攻速 (比例累加,显示整数百分比).
			var total_pct: int = _pct(res.effect_params[0], count)
			return instance.tr("PASSIVE_STACKED_ATTACK_SPEED_UP").format([total_pct], "{_}")
		ITEM_ID_MOVE_SPEED_UP:
			# effect_params[0] = 0.1, 每级 +10% 移速 (比例累加,显示整数百分比).
			var total_pct: int = _pct(res.effect_params[0], count)
			return instance.tr("PASSIVE_STACKED_MOVE_SPEED_UP").format([total_pct], "{_}")
		ITEM_ID_DEFENCE_UP:
			# effect_params[0] = 0.8, 每级承受伤害乘 0.8; 显示总减伤百分比 = (1 - 0.8^count) * 100.
			var final_ratio: float = float(res.effect_params[0]) ** count
			var reduce_pct: int = snappedi((1.0 - final_ratio) * 100.0, 1)
			return instance.tr("PASSIVE_STACKED_DEFENCE_UP").format([reduce_pct], "{_}")
		ITEM_ID_BULLET_SPLIT:
			# effect_params[0] = 2(每档新增弹道数); effect_params[1] = 0.7(单发伤害系数,累乘).
			if res.effect_params.size() > 1:
				var added_bullets: int = int(float(res.effect_params[0]) * count)
				var dmg_ratio: float = float(res.effect_params[1]) ** count
				var dmg_pct: int = snappedi(dmg_ratio * 100.0, 1)
				return instance.tr("PASSIVE_STACKED_BULLET_SPLIT").format([added_bullets, dmg_pct], "{_}")
	# 回退: 用单级描述.
	return formatted_description(res)


## 格式化单个 effect_params 值(用于模板着色). 保留"比例"还是"数值"的语义决策在 CSV / 翻译模板,这里只做转字符串显示.
static func _format_value(param) -> String:
	match typeof(param):
		TYPE_FLOAT:
			# 0~1 范围内且不是整数 的小数视为比例 -> 显示整数百分比 (如 0.1 -> "10%").
			# 其他浮点保持最多 2 位小数.
			if param > 0.0 and param < 1.0 and not is_equal_approx(param, snappedf(param, 1.0)):
				return "%d%%" % snappedi(param * 100.0, 1)
			if is_equal_approx(param, snappedf(param, 1.0)):
				return str(int(param))
			return ("%.2f" % param).rstrip("0").rstrip(".")
		TYPE_INT:
			return str(param)
		_:
			return str(param)


## 辅助: 把 per_level_rate(浮点比例,如 0.1)累加 count 次后投射为整数百分比 (10, 20, 30...).
## 先用 snappedi 处理浮点精度后再取整, 避免 0.1*3*100=29.99... 取到 29.
static func _pct(per_level_rate, count: int) -> int:
	return snappedi(per_level_rate * count * 100.0, 1)


## 免费升级: 奖励关拾取物触发. 不走全玩家同步流程, 单人次直接应用 (instance method)
func apply_free_upgrade(peer_id: int) -> void:
	if resources_id_dict.is_empty():
		return
	var all_passives := resources_id_dict.keys()
	var chosen: String = all_passives[randi() % all_passives.size()]
	_apply_passive_upgrade(peer_id, chosen)


## 奖励关中指定被动物品的升级 (泡泡中已展示具体升级类型)
func apply_specific_upgrade(peer_id: int, passive_id: String) -> void:
	if not resources_id_dict.has(passive_id):
		push_warning("[UpgradeComponent] apply_specific_upgrade: unknown passive_id %s" % passive_id)
		return
	_apply_passive_upgrade(peer_id, passive_id)


## 内部实现: 记录被动次数并通知对应玩家
func _apply_passive_upgrade(peer_id: int, passive_id: String) -> void:
	var peer_passive_count_dic: Dictionary = peer_selected_passives.get_or_add(peer_id, {})
	var count: int = peer_passive_count_dic.get_or_add(passive_id, 0)
	peer_passive_count_dic[passive_id] = count + 1
	var res: PassiveItemResource = resources_id_dict.get(passive_id)
	var upgrade_name: String = instance.tr(res.name_key)
	KLogger.info("[UpgradeLog] peer %s picked up upgrade: %s" % [peer_id, upgrade_name])
	_log_peer_upgrades(peer_id, peer_selected_passives)
	# 通知拾取的玩家 (客户端 + 主控玩家节点), 触发 HUD / 音效反馈
	_notify_peer_pickup_bonus.rpc(peer_id, passive_id)
	# 广播被动数量变化给所有 peer (客户端缓存)
	_notify_passive_changed.rpc(peer_id, passive_id, count + 1)

@rpc("authority", "call_remote", "reliable")
func _notify_peer_pickup_bonus(peer_id: int, passive_id: String) -> void:
	# 在拾取者所在的客户端本地触发 HUD / 音效反馈
	if multiplayer.get_unique_id() != peer_id:
		return
	# 播放拾取升级音效 (仅在玩家自己客户端本地)
	SoundManager.play_select()
	var self_player: Player = null
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.input_peer_id == peer_id:
			self_player = p
			break
	if self_player:
		self_player._on_free_upgrade_applied(passive_id)


## 广播被动道具数量变化给所有 peer, 客户端缓存到 client_passive_counts
@rpc("authority", "call_local", "reliable")
func _notify_passive_changed(peer_id: int, passive_id: String, new_count: int) -> void:
	if peer_id not in client_passive_counts:
		client_passive_counts[peer_id] = {}
	if new_count <= 0:
		client_passive_counts[peer_id].erase(passive_id)
		if client_passive_counts[peer_id].is_empty():
			client_passive_counts.erase(peer_id)
	else:
		client_passive_counts[peer_id][passive_id] = new_count
	# 通知 UI 刷新
	_emit_passive_changed_signals(peer_id)


## 客户端根据缓存的被动数量, 触发 GameEvents 信号驱动 UI 刷新
func _emit_passive_changed_signals(peer_id: int) -> void:
	var my_id: int = multiplayer.get_unique_id()
	if peer_id != my_id:
		return
	# 仅本地主控玩家刷新 UI
	if not client_passive_counts.has(my_id):
		return
	var my_passives: Dictionary = client_passive_counts[my_id]
	# 刷新被动持有横栏
	GameEvents.emit_local_player_passives_changed(my_passives)
	# 刷新属性详情面板(如果可见)
	if _stats_panel_instance and is_instance_valid(_stats_panel_instance):
		_stats_panel_instance.refresh(my_passives)


## 客户端缓存查询接口 (供 UI 读取)
static func get_client_passive_counts() -> Dictionary:
	if not is_instance_valid(instance):
		return {}
	return instance.client_passive_counts


func get_my_passive_counts() -> Dictionary:
	var my_id: int = multiplayer.get_unique_id()
	return client_passive_counts.get(my_id, {})


## 属性详情面板实例引用 (由面板 _ready 时注册)
var _stats_panel_instance: Node = null

func register_stats_panel(panel: Node) -> void:
	_stats_panel_instance = panel

func unregister_stats_panel(panel: Node) -> void:
	if _stats_panel_instance == panel:
		_stats_panel_instance = null
