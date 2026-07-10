class_name PlayerStatsPanel
extends Control

## 属性详情面板 (Tab 呼出). 双列对比展示基础值 → 当前值 ± 差值.

const COLOR_POSITIVE := Color(0.45, 1.0, 0.55, 1.0)  # 绿色 - 提升
const COLOR_NEGATIVE := Color(1.0, 0.45, 0.45, 1.0)  # 红色 - 下降
const COLOR_NEUTRAL := Color(0.85, 0.85, 0.85, 1.0)  # 灰色 - 不变

## 单行属性
class StatRow:
	var name_key: String = ""
	var base_format: String = "%.0f"
	var current_format: String = "%.0f"
	var unit: String = ""
	var node: HBoxContainer
	var name_label: Label
	var base_label: Label
	var current_label: Label
	var diff_label: Label

	func _init() -> void:
		node = HBoxContainer.new()
		name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", 14)
		base_label = Label.new()
		base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_label.add_theme_font_size_override("font_size", 14)
		var arrow_label := Label.new()
		arrow_label.text = "→"
		arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_label.add_theme_font_size_override("font_size", 14)
		current_label = Label.new()
		current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		current_label.add_theme_font_size_override("font_size", 14)
		diff_label = Label.new()
		diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diff_label.add_theme_font_size_override("font_size", 13)
		node.add_child(name_label)
		node.add_child(base_label)
		node.add_child(arrow_label)
		node.add_child(current_label)
		node.add_child(diff_label)

	func set_values(base_val: float, current_val: float) -> void:
		name_label.text = tr(name_key)
		var unit_str: String = (" " + unit) if unit != "" else ""
		base_label.text = (base_format % base_val) + unit_str
		current_label.text = (current_format % current_val) + unit_str
		var diff: float = current_val - base_val
		if is_equal_approx(diff, 0.0):
			diff_label.text = "±0"
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_NEUTRAL)
		elif diff > 0.0:
			diff_label.text = ("+" + _format_diff(diff, current_format)) + unit_str
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_POSITIVE)
		else:
			diff_label.text = (_format_diff(diff, current_format)) + unit_str
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_NEGATIVE)

	static func _format_diff(value: float, fmt: String) -> String:
		var s: String = (fmt % abs(value)).lstrip("-")
		if s.contains("."):
			s = s.rstrip("0").rstrip(".")
		return s


var _stat_rows: Array = []

@onready var title_label: Label = %TitleLabel
@onready var footer_label: Label = %FooterLabel
@onready var stat_rows_container: VBoxContainer = %StatRows

## 如果 unique_name 找不到, 用路径查找作为 fallback
func _ensure_node_refs() -> void:
	if not is_instance_valid(title_label):
		title_label = get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	if not is_instance_valid(footer_label):
		footer_label = get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FooterLabel")
	if not is_instance_valid(stat_rows_container):
		stat_rows_container = get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatRows")


func _ready() -> void:
	_ensure_node_refs()
	title_label.text = tr("STATS_PANEL_TITLE")
	footer_label.text = tr("STATS_PANEL_FOOTER")
	# 向 UpgradeComponent 注册自己
	if is_instance_valid(UpgradeComponent.instance):
		UpgradeComponent.instance.register_stats_panel(self)
	# 构建属性行
	_build_stat_rows()
	visible = false


func _exit_tree() -> void:
	if is_instance_valid(UpgradeComponent.instance):
		UpgradeComponent.instance.unregister_stats_panel(self)


## 由 UpgradeComponent 被动变化通知触发
func refresh(_passives: Dictionary) -> void:
	if visible:
		_refresh_stat_rows()


func toggle(visible_: bool) -> void:
	visible = visible_
	if visible:
		_refresh_stat_rows()


func _build_stat_rows() -> void:
	# 6 行: 子弹伤害 / 射速 / 移速 / 血量上限 / 伤害承受 / 弹道数
	var rows: Array[Dictionary] = [
		{"name_key": "STAT_BULLET_DAMAGE", "base_format": "%.0f", "current_format": "%.2f", "unit": ""},
		{"name_key": "STAT_FIRE_RATE", "base_format": "%.2f", "current_format": "%.2f", "unit": "s"},
		{"name_key": "STAT_MOVE_SPEED", "base_format": "%.0f", "current_format": "%.0f", "unit": ""},
		{"name_key": "STAT_HEALTH_LIMIT", "base_format": "%.0f", "current_format": "%.0f", "unit": ""},
		{"name_key": "STAT_DAMAGE_REDUCTION", "base_format": "%.0f", "current_format": "%.0f", "unit": "%"},
		{"name_key": "STAT_BULLET_COUNT", "base_format": "%d", "current_format": "%d", "unit": ""},
	]
	for r in rows:
		var row = StatRow.new()
		row.name_key = r["name_key"]
		row.base_format = r["base_format"]
		row.current_format = r["current_format"]
		row.unit = r["unit"]
		stat_rows_container.add_child(row.node)
		_stat_rows.append(row)
	_refresh_stat_rows()


func _refresh_stat_rows() -> void:
	var my_id: int = multiplayer.get_unique_id()
	# 基础值
	var base_damage: float = Player.BASE_BULLET_DAMAGE
	var base_fire_rate: float = Player.BASE_FIRE_RATE
	var base_move_speed: float = Player.BASE_MOVE_SPEED
	var base_health_limit: float = Player.BASE_HEALTH_LIMIT
	var base_bullet_count: int = 1
	# 当前值
	var cur_damage: float = UpgradeComponent.calc_bullet_damage(my_id, base_damage)
	var cur_fire_rate: float = UpgradeComponent.calc_fire_rate(my_id, base_fire_rate)
	var cur_move_speed: float = UpgradeComponent.calc_move_speed(my_id, base_move_speed)
	var cur_health_limit: float = UpgradeComponent.calc_health_limit(my_id, base_health_limit)
	var cur_defence: float = UpgradeComponent.calc_defence(my_id)
	var cur_bullet_count: int = UpgradeComponent.calc_bullet_count(my_id)
	# 防御以"减伤百分比"显示
	var base_def_display: float = 0.0
	var cur_def_display: float = (1.0 - cur_defence) * 100.0
	# 更新各行
	_stat_rows[0].set_values(base_damage, cur_damage)
	_stat_rows[1].set_values(base_fire_rate, cur_fire_rate)
	_stat_rows[2].set_values(base_move_speed, cur_move_speed)
	_stat_rows[3].set_values(base_health_limit, cur_health_limit)
	_stat_rows[4].set_values(base_def_display, cur_def_display)
	_stat_rows[5].set_values(float(base_bullet_count), float(cur_bullet_count))
