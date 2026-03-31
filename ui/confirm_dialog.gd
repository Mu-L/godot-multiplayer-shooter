class_name ConfirmDialog
extends Control


signal confirmd

var title: String = "Error"
var message: String = "There is something happend"

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	title_label.text = title
	message_label.text = message
	confirm_button.pressed.connect(_on_confirm_button_pressed)


func _on_confirm_button_pressed() -> void:
	queue_free()
	confirmd.emit()
