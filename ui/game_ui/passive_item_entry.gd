class_name PassiveItemEntry
extends Control

## 被动道具持有横栏中的单个道具项. 显示图标 + 数字角标, 鼠标指向触发 Tooltip.


const TOOLTIP_PANEL = preload("res://ui/components/tooltip_panel.tscn")

var passive_id: String = ""
var count: int = 0

@onready var icon_texture: TextureRect = %IconTexture
@onready var count_label: Label = %CountLabel


func setup(passive_id_: String, count_: int, icon: Texture2D) -> void:
	passive_id = passive_id_
	count = count_
	icon_texture.texture = icon
	count_label.text = str(count)
	visible = count > 0


func _make_custom_tooltip(_for_text: String) -> Object:
	var _tooltip = TOOLTIP_PANEL.instantiate() as TooltipPanel
	_tooltip.setup(passive_id, count)
	return _tooltip
