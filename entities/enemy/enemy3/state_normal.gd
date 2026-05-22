extends State

## Enemy的正常状态,追踪最近玩家并在近距离攻击

const ATTACK_DISTANCE_SQUARED: float = 2025.0

var enemy: Variant


func _ready() -> void:
	enemy = owner


func enter() -> void:
	enemy.set_attack_visual(false)
	if is_multiplayer_authority():
		enemy.update_track_target()


func update() -> void:
	if is_multiplayer_authority():
		if enemy.has_track_target:
			enemy.velocity = enemy.global_position.direction_to(enemy.track_target) * enemy.MOVE_SPEED
			play_move_effects.rpc(true)
			var squared_distance: float = enemy.global_position.distance_squared_to(enemy.track_target)
			if squared_distance < ATTACK_DISTANCE_SQUARED and enemy.attack_cool_down_timer.is_stopped():
				enemy.attack_cool_down_timer.start()
				transitioned.emit("charge")
		else:
			enemy.velocity = Vector2.ZERO
			play_move_effects.rpc(false)
	enemy.update_direction()


func exit() -> void:
	enemy.move_animation_player.play("RESET")


@rpc("authority", "call_local")
func play_move_effects(play: bool) -> void:
	if play:
		enemy.move_animation_player.play("move")
	else:
		enemy.move_animation_player.play("RESET")
