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
	## 为 true 时 diff 越小(负)越绿, 越大(正)越红. 用于"间隔"类属性(攻击间隔: 变小=变快=好)
	var invert_diff_color: bool = false
	var node: HBoxContainer
	var name_label: Label
	var base_label: Label
	var arrow_label: Label
	var current_label: Label
	var diff_label: Label
	## 动态段标签(基础伤害多段显示), 每次 set_values 重置
	var _segment_labels: Array[Label] = []

	func _init() -> void:
		node = HBoxContainer.new()
		name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", 14)
		base_label = Label.new()
		base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_label.add_theme_font_size_override("font_size", 14)
		arrow_label = Label.new()
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

	## segments: 在 base 与 current 之间插入的中间段. 每项 { "text": String, "color": Color }.
	## 用于子弹伤害多段显示: base →(+bonus 绿)→ pre_split →(×factor 红)→ final.
	func set_values(base_val: float, current_val: float, segments: Array[Dictionary] = []) -> void:
		name_label.text = name_key
		var unit_str: String = (" " + unit) if unit != "" else ""
		base_label.text = (base_format % base_val) + unit_str
		# 有中间段时当前值也带前导箭头, 保持链式连贯: ... → final
		var chain_prefix: String = "→ " if segments.size() > 0 else ""
		current_label.text = chain_prefix + (current_format % current_val) + unit_str
		# 清理旧段
		for seg_label in _segment_labels:
			seg_label.queue_free()
		_segment_labels.clear()
		# 有中间段时隐藏父级箭头 (段与段之间靠每段自带前缀箭头连接)
		arrow_label.visible = segments.size() == 0
		# 在 arrow 之后插入中间段 (arrow 位于子节点 index 2)
		for i in range(segments.size()):
			var seg: Dictionary = segments[i]
			var seg_label := Label.new()
			seg_label.add_theme_font_size_override("font_size", 12)
			seg_label.text = seg.get("text", "")
			seg_label.add_theme_color_override("font_color", seg.get("color", PlayerStatsPanel.COLOR_NEUTRAL))
			node.add_child(seg_label)
			node.move_child(seg_label, 2 + i)
			_segment_labels.append(seg_label)
		# diff 颜色: invert_diff_color 时符号取反(间隔类属性)
		var diff: float = current_val - base_val
		var positive_good: bool = not invert_diff_color
		if is_equal_approx(diff, 0.0):
			diff_label.text = "±0"
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_NEUTRAL)
		elif diff > 0.0:
			diff_label.text = ("+" + _format_diff(diff, current_format)) + unit_str
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_POSITIVE if positive_good else PlayerStatsPanel.COLOR_NEGATIVE)
		else:
			diff_label.text = (_format_diff(diff, current_format)) + unit_str
			diff_label.add_theme_color_override("font_color", PlayerStatsPanel.COLOR_NEGATIVE if positive_good else PlayerStatsPanel.COLOR_POSITIVE)

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
	# 6 行: 子弹伤害 / 攻击间隔 / 移速 / 血量上限 / 减伤 / 弹道数
	var rows: Array[Dictionary] = [
		{"name_key": tr("STAT_BULLET_DAMAGE"), "base_format": "%.0f", "current_format": "%.2f", "unit": ""},
		{"name_key": tr("STAT_ATTACK_INTERVAL"), "base_format": "%.2f", "current_format": "%.2f", "unit": "s", "invert_diff_color": true},
		{"name_key": tr("STAT_MOVE_SPEED"), "base_format": "%.0f", "current_format": "%.0f", "unit": ""},
		{"name_key": tr("STAT_HEALTH_LIMIT"), "base_format": "%.0f", "current_format": "%.0f", "unit": ""},
		{"name_key": tr("STAT_DAMAGE_REDUCTION"), "base_format": "%.0f", "current_format": "%.0f", "unit": "%"},
		{"name_key": tr("STAT_BULLET_COUNT"), "base_format": "%d", "current_format": "%d", "unit": ""},
	]
	for r in rows:
		var row = StatRow.new()
		row.name_key = r["name_key"]
		row.base_format = r["base_format"]
		row.current_format = r["current_format"]
		row.unit = r["unit"]
		row.invert_diff_color = r.get("invert_diff_color", false)
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
	# 当前值 (子弹伤害使用逐段拆解)
	var damage_breakdown: Dictionary = UpgradeComponent.calc_bullet_damage_breakdown(my_id, base_damage)
	var cur_damage: float = damage_breakdown["final"]
	var cur_fire_rate: float = UpgradeComponent.calc_fire_rate(my_id, base_fire_rate)
	var cur_move_speed: float = UpgradeComponent.calc_move_speed(my_id, base_move_speed)
	var cur_health_limit: float = UpgradeComponent.calc_health_limit(my_id, base_health_limit)
	var cur_defence: float = UpgradeComponent.calc_defence(my_id)
	var cur_bullet_count: int = UpgradeComponent.calc_bullet_count(my_id)
	# 防御以"减伤百分比"显示
	var base_def_display: float = 0.0
	var cur_def_display: float = (1.0 - cur_defence) * 100.0
	# 子弹伤害多段链: base →(+bonus 绿)→ pre_split →(×factor 红)→ final
	var segments: Array[Dictionary] = _format_bullet_damage_segments(damage_breakdown)
	# 更新各行
	_stat_rows[0].set_values(damage_breakdown["base"], cur_damage, segments)
	_stat_rows[1].set_values(base_fire_rate, cur_fire_rate)
	_stat_rows[2].set_values(base_move_speed, cur_move_speed)
	_stat_rows[3].set_values(base_health_limit, cur_health_limit)
	_stat_rows[4].set_values(base_def_display, cur_def_display)
	_stat_rows[5].set_values(float(base_bullet_count), float(cur_bullet_count))


## 根据子弹伤害逐段拆解, 生成 base 与 current 之间的多段标签.
## 链: base → (+bonus 绿色) → pre_split → (×factor 红色) → final
## 每段自带前导箭头(父级箭头已隐藏); 无分裂时仅显示加成段(若有), 避免空渲染.
static func _format_bullet_damage_segments(breakdown: Dictionary) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if breakdown["bonus"] > 0.0:
		var bonus_text: String = ("+%s" % PlayerStatsPanel._format_damage_value(breakdown["bonus"])) if breakdown["bonus"] >= 0.0 else ("-%s" % PlayerStatsPanel._format_damage_value(abs(breakdown["bonus"])))
		segments.append({"text": ("→ %s" % bonus_text), "color": PlayerStatsPanel.COLOR_POSITIVE})
		segments.append({"text": ("→ %s" % PlayerStatsPanel._format_damage_value(breakdown["pre_split"])), "color": PlayerStatsPanel.COLOR_NEUTRAL})
	if breakdown["is_split_active"]:
		segments.append({"text": ("→ ×%s" % PlayerStatsPanel._format_damage_value(breakdown["split_factor"])), "color": PlayerStatsPanel.COLOR_NEGATIVE})
	return segments


static func _format_damage_value(value: float) -> String:
	# 整数显示整数, 否则最多 2 位小数去尾零
	if is_equal_approx(value, snappedf(value, 1.0)):
		return str(int(value))
	return ("%.2f" % value).rstrip("0").rstrip(".")
