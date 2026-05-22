extends State

## Enemy进入短暂蓄力攻击状态

var enemy: Variant


func enter() -> void:
	enemy = owner
	enemy.show_charge_tip()
	if is_multiplayer_authority():
		enemy.velocity = Vector2.ZERO
		await get_tree().create_timer(0.25).timeout
		if enemy.state_machine.current_state == "charge":
			transitioned.emit("attack")


func update() -> void:
	if is_multiplayer_authority():
		enemy.velocity_down()


func exit() -> void:
	enemy.hide_charge_tip()
