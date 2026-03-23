extends State

## Enemy的正常状态,允许移动

const MAX_ATTACK_DISTANCE_SQUARED: float = 10000

var enemy: Enemy

func enter() -> void:
	enemy = owner
	if is_multiplayer_authority():
		enemy.update_track_target()


func update() -> void:
	# 服务器逻辑
	if is_multiplayer_authority():
		# 如果有跟踪目标,则设置速度,向目标移动
		if enemy.has_track_target:
			enemy.velocity = enemy.global_position.direction_to(enemy.track_target) * 40
			# 如果距离目标玩家距离小于一定值,准备攻击
			if enemy.global_position.distance_squared_to(enemy.track_target) < MAX_ATTACK_DISTANCE_SQUARED:
				if enemy.attack_cool_down_timer.is_stopped():
					enemy.attack_cool_down_timer.start()
					transitioned.emit("charge")
	# 显示/动画 -- 所有peer
	enemy.update_direction()
