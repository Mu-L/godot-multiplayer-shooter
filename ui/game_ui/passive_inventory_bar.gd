class_name PassiveInventoryBar
extends HBoxContainer

## 被动道具持有横栏. 放在 PlayerHealthUI 血条下方, 横向显示持有物品的图标 + 数字角标.
## 鼠标指向图标时弹出 TooltipPanel 显示单级效果 + 叠加效果.

const PASSIVE_ITEM_ENTRY = preload("res://ui/game_ui/passive_item_entry.tscn")
const TOOLTIP_PANEL = preload("res://ui/components/tooltip_panel.tscn")

var _entries: Array = []


func _ready() -> void:
	# 监听被动变化
	GameEvents.local_player_passives_changed.connect(_on_local_player_passives_changed)
	# 初始刷新
	if is_instance_valid(UpgradeComponent.instance):
		_refresh(UpgradeComponent.instance.get_my_passive_counts())


func _on_local_player_passives_changed(passives: Dictionary) -> void:
	_refresh(passives)


func _refresh(passives: Dictionary) -> void:
	# 清理旧条目
	for entry in _entries:
		entry.queue_free()
	_entries.clear()
	if passives == null or passives.is_empty():
		return
	# 按固定顺序排列 (与 UpgradeComponent 常量顺序一致)
	var order: Array[String] = [
		UpgradeComponent.ITEM_ID_BASIC_DAMAGE_UP,
		UpgradeComponent.ITEM_ID_BULLET_SPLIT,
		UpgradeComponent.ITEM_ID_ATTACK_SPEED_UP,
		UpgradeComponent.ITEM_ID_MOVE_SPEED_UP,
		UpgradeComponent.ITEM_ID_HEALTH_LIMIT_UP,
		UpgradeComponent.ITEM_ID_DEFENCE_UP,
	]
	for passive_id in order:
		if not passive_id in passives:
			continue
		var count: int = passives[passive_id]
		if count <= 0:
			continue
		var res: PassiveItemResource = _get_resource(passive_id)
		if res == null:
			continue
		var entry = PASSIVE_ITEM_ENTRY.instantiate()
		add_child(entry)
		entry.setup(passive_id, count, res.icon)
		_entries.append(entry)


func _get_resource(passive_id: String) -> PassiveItemResource:
	if is_instance_valid(UpgradeComponent.instance):
		var res: PassiveItemResource = UpgradeComponent.instance.resources_id_dict.get(passive_id)
		if res != null:
			return res
	for r in CSVResourceCache.get_all_passives():
		if r.id == passive_id:
			return r
	return null
