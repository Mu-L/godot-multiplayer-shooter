class_name TooltipPanel
extends PopupPanel

## 被动道具悬浮提示面板. 由 PassiveInventoryBar 在鼠标进入图标时调用 show_tooltip().

const SINGLE_HEADER_DEFAULT := "一级效果"
const STACKED_HEADER_DEFAULT := "叠加效果"

@onready var title_label: Label = %TitleLabel
@onready var icon_texture: TextureRect = %IconTexture
@onready var separator_2: HSeparator = %Separator2
@onready var single_header: Label = %SingleHeader
@onready var single_description: Label = %SingleDescription
@onready var stacked_header: Label = %StackedHeader
@onready var stacked_description: Label = %StackedDescription


func _ready() -> void:
	single_header.text = SINGLE_HEADER_DEFAULT
	stacked_header.text = STACKED_HEADER_DEFAULT


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
	# 单级效果
	single_description.text = UpgradeComponent.formatted_description(res)
	# 叠加效果 (count == 1 时与单级相同, 但仍显示)
	if count <= 1:
		stacked_description.text = single_description.text
	else:
		stacked_description.text = UpgradeComponent.formatted_description_stacked(res, count)
	# 当 count == 1 时隐藏叠加区段分隔线和标题
	var show_stacked: bool = count > 1
	separator_2.visible = show_stacked
	stacked_header.visible = show_stacked
	stacked_description.visible = show_stacked
	# 弹出到鼠标位置
	var mouse_pos: Vector2i = DisplayServer.mouse_get_position()
	popup(Rect2i(mouse_pos + Vector2i(12, 12), Vector2i.ZERO))
