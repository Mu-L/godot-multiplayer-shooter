# roar_visual_ring.gd (挂载在怪物的子节点 Node2D)
class_name VisualRing
extends Node2D

signal wave_triggered

# 触发参数
@export var max_radius: float = 200.0
@export var duration: float = 0.7
@export var trigger_times: int = 1
@export var trigger_interval: float = 0.15
@export var wave_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var line_width: float = 3.0
@export var arc_points: int = 64

# 保存每个活跃光波的存活时间 (秒)
var _active_waves: Array[float] = []

# 触发队列控制
var _waves_left: int = 0
var _spawn_timer: float = 0.0


func _ready() -> void:
	_active_waves.clear()
	_waves_left = trigger_times
	_spawn_timer = 0.0


func _process(delta: float) -> void:
	# 1. 触发间隔计时与波纹发射
	if _waves_left > 0:
		_spawn_timer -= delta
		while _spawn_timer <= 0.0 and _waves_left > 0:
			# abs(_spawn_timer) 用于补偿帧间隔引起的亚帧发射误差
			_active_waves.append(abs(_spawn_timer))
			_waves_left -= 1
			_spawn_timer += trigger_interval
			wave_triggered.emit()
	# 2. 更新所有波纹的生命周期
	var needs_redraw: bool = not _active_waves.is_empty()
	for i in range(_active_waves.size() - 1, -1, -1):
		_active_waves[i] += delta
		if _active_waves[i] >= duration:
			_active_waves.remove_at(i)
	# 3. 仅在有活动波纹或刚清空时触发重绘
	if needs_redraw:
		queue_redraw()
	else:
		queue_free()


func _draw() -> void:
	for elapsed in _active_waves:
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		# Quad Ease-Out
		var r_factor: float = t * (2.0 - t)
		var current_radius: float = max_radius * r_factor
		# Cubic Ease-In (Fade out)
		var a_factor: float = 1.0 - (t * t * t)
		var current_color: Color = wave_color
		current_color.a *= a_factor
		if current_radius > 0.0 and current_color.a > 0.0:
			draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, arc_points, current_color, line_width, true)
