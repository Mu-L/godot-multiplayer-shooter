extends State

## Enemy进入攻击状态,切换攻击资源并维持范围伤害判定

const ATTACK_DURATION: float = 2.0

var enemy: Enemy3


func enter() -> void:
	enemy = owner
	enemy.set_attack_visual(true)
	if is_multiplayer_authority():
		enemy.velocity = Vector2.ZERO
		enemy.start_attack_collision()
		await get_tree().create_timer(ATTACK_DURATION).timeout
		if enemy.state_machine.current_state == "attack":
			transitioned.emit("normal")


func update() -> void:
	if is_multiplayer_authority():
		enemy.velocity = Vector2.ZERO


func exit() -> void:
	if is_multiplayer_authority():
		enemy.stop_attack_collision()
