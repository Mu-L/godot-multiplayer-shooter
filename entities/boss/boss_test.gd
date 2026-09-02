extends Node2D

func _ready() -> void:
	KLogger.get_module().set_output_level(KLogger.DEBUG)
