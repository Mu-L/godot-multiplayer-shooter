@tool
extends AtomicState

@export var boss: Boss


var dodge_speed: float = 650.0       # 闪避初速度
var dodge_duration: float = 0.35     # 闪避持续时间 (秒)

var dodge_timer_elapsed: float

func _ready() -> void:
	super()
	state_entered.connect(_on_state_entered)
	state_exited.connect(_on_state_exited)
	state_processing.connect(_on_state_processing)
	state_physics_processing.connect(_on_state_physics_processing)


# 计算最佳闪避逃逸方向
func _calculate_dodge_direction() -> Vector2:
	# 过滤掉已被销毁的子弹
	var valid_bullets = boss.big_area_bullets.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	if valid_bullets.is_empty():
		return Vector2.ZERO
	
	var highest_threat_bullet: Node2D = null
	var min_tti: float = INF # 最小碰撞时间 (Time to Impact)
	var best_escape_dir: Vector2 = Vector2.ZERO
	
	for bullet in valid_bullets:
		# 获取子弹速度 (兼容不同子弹实现: velocity 属性或基于全局朝向)
		var b_vel: Vector2 = Vector2.ZERO
		if "velocity" in bullet:
			b_vel = bullet.velocity
		elif "speed" in bullet:
			b_vel = Vector2.RIGHT.rotated(bullet.global_rotation) * bullet.speed
		else:
			continue
		
		var b_speed = b_vel.length()
		if b_speed < 10.0:
			continue
		
		var b_dir = b_vel.normalized()
		var to_boss = boss.global_position - bullet.global_position
		
		# 1. 忽略朝 Boss 背向飞行的子弹
		var forward_proj = to_boss.dot(b_dir)
		if forward_proj <= 0.0:
			continue
		
		# 2. 计算点到直线的投影点
		var proj_point = bullet.global_position + b_dir * forward_proj
		var dist_to_trajectory = boss.global_position.distance_to(proj_point)
		
		# 3. 如果弹道偏差大于安全距离 (例如 Boss 半径 30 + 冗余 20 = 50), 不构成威胁
		if dist_to_trajectory > 50.0:
			continue
		
		# 4. 计算预计命中时间 (TTI)
		var tti = forward_proj / b_speed
		if tti < min_tti:
			min_tti = tti
			highest_threat_bullet = bullet
			
			# 从投影点指向 Boss 的向量, 即为最快脱离弹道的切线方向
			var escape = boss.global_position - proj_point
			if escape.length_squared() < 1.0:
				# Boss 正好在弹道轴心上, 任选一侧垂直方向
				escape = Vector2(-b_dir.y, b_dir.x)
			best_escape_dir = escape.normalized()
	
	if highest_threat_bullet == null:
		return Vector2.ZERO
	
	# # 5. 防撞墙安全探测: 沿 escape_dir 探测 80px 距离
	# var test_transform = global_transform
	# if test_move(test_transform, best_escape_dir * 80.0):
	# 	# 撞墙时反转到相反切向
	# 	best_escape_dir = -best_escape_dir
		
	return best_escape_dir


func _on_state_entered() -> void:
	KLogger.info("action state: 'dodge' entered")
	dodge_timer_elapsed = 0.0
	boss.speed_offset = boss.current_speed * 4.0
	dodge_speed = boss.current_speed + boss.speed_offset
	boss.animation_tween.play()
	# 计算躲避方向
	var dir = _calculate_dodge_direction()
	if dir == Vector2.ZERO:
		# 没有明确危险弹道时, 随机侧移或朝当前朝向垂直侧移
		dir = Vector2.UP.rotated(randf() * TAU)
	boss.move_direction = dir


func _on_state_exited() -> void:
	boss.speed_offset = 0
	boss.animation_tween.stop()
	boss.animation.scale = Vector2.ONE
	boss.dodge_timer.start()


func _on_state_processing(delta: float) -> void:
	dodge_timer_elapsed += delta
	# 速度平滑指数衰减 (营造短促冲刺感)
	boss.speed_offset -= (dodge_speed / dodge_duration) * delta

	# 动作完成, 退出回到 Idle
	if dodge_timer_elapsed >= dodge_duration:
		boss.state_chart.send_event("to_idle")


func _on_state_physics_processing(_delta: float) -> void:
	pass
