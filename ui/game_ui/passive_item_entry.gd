class_name PassiveItemEntry
extends Control

## 被动道具持有横栏中的单个道具项. 显示图标 + 数字角标, 鼠标指向触发 Tooltip.

signal tooltip_requested(passive_id: String, count: int, entry: PassiveItemEntry)

var passive_id: String = ""
var count: int = 0

@onready var icon_texture: TextureRect = %IconTexture
@onready var count_label: Label = %CountLabel
@onready var hover_detector: Control = %HoverDetector


func _ready() -> void:
	hover_detector.mouse_entered.connect(_on_mouse_entered)
	hover_detector.mouse_exited.connect(_on_mouse_exited)


func setup(passive_id_: String, count_: int, icon: Texture2D) -> void:
	passive_id = passive_id_
	count = count_
	icon_texture.texture = icon
	count_label.text = str(count)
	visible = count > 0


func _on_mouse_entered() -> void:
	if count <= 0:
		return
	tooltip_requested.emit(passive_id, count, self)


func _on_mouse_exited() -> void:
	# 由父容器统一隐藏 Tooltip
	pass
