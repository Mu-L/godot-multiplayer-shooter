class_name TooltipPanel
extends Control

## 被动道具悬浮提示面板. 由 PassiveInventoryBar 在鼠标进入图标时调用 show_tooltip().

@onready var title_label: Label = %TitleLabel
@onready var icon_texture: TextureRect = %IconTexture
@onready var separator_2: HSeparator = %Separator2
@onready var single_header: Label = %SingleHeader
@onready var single_description: Label = %SingleDescription
@onready var stacked_header: Label = %StackedHeader
@onready var stacked_description: Label = %StackedDescription


var init_passive_id: String
var init_count: int


func _ready() -> void:
	single_header.text = tr("SINGLE_TOOL_TIP_HEADER")
	stacked_header.text = tr("STACKED_TOOL_TIP_HEADER")
	show_tooltip(init_passive_id, init_count)


func setup(_passive_id: String, _count: int) -> void:
	init_passive_id = _passive_id
	init_count = _count


## 填充并显示提示. passive_id 为道具 id, count 为当前持有数.
func show_tooltip(passive_id: String, count: int) -> void:
	if count <= 0:
		return
	var res: PassiveItemResource = null
	if is_instance_valid(UpgradeComponent.instance):
		res = UpgradeComponent.instance.resources_id_dict.get(passive_id)
	if res == null:
		# 客户端缓存中可能没有 resource, 尝试从 CSVResourceCache 取
		for r in CSVResourceCache.get_all_passives():
			if r.id == passive_id:
				res = r
				break
	if res == null:
		return
	title_label.text = tr(res.name_key)
	icon_texture.texture = res.icon
	# 单级效果: 使用翻译模板 PASSIVE_ITEM_*_DESCRIPTION, 代入 effect_params 原始数值.
	single_description.text = UpgradeComponent.formatted_description(res)
	# 叠加效果: 每种道具的叠加语义独立(整数累加 / 比例累加 / 累乘 / 混合).
	var show_stacked: bool = count > 1
	if show_stacked:
		stacked_description.text = UpgradeComponent.formatted_description_stacked(res, count)
	# 当 count == 1 时隐藏叠加区段分隔线和标题
	separator_2.visible = show_stacked
	stacked_header.visible = show_stacked
	stacked_description.visible = show_stacked
