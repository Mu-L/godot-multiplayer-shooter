class_name RangeIndicator
extends Node2D


@export var mesh: MeshInstance2D

var size: Vector2:
	get:
		return mesh.scale
	set(value):
		mesh.scale = value


var progress: float:
	get:
		return mesh.material.get("shader_parameter/progress")
	set(value):
		mesh.material.set("shader_parameter/progress", value)
