# roar_visual_ring.gd (挂载在怪物的子节点 Node2D)
class_name VisualRing
extends Node2D

var _radius: float = 0.0
var _alpha: float = 1.0


func trigger(max_radius: float, duration: float) -> void:
	_radius = 0.0
	_alpha = 0.8
	show()
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "_radius", max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_alpha", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(hide)


func _process(_delta: float) -> void:
	if is_visible():
		queue_redraw()


func _draw() -> void:
	if _radius > 0.0:
		# 绘制空心音波光圈
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(1.0, 0.9, 0.6, _alpha), 4.0, true)
