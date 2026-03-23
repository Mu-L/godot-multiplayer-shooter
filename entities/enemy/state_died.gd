extends State

## Enemy的死亡状态

var enemy: Enemy

func enter() -> void:
	enemy = owner
	GameEvents.emit_enemy_died()
	enemy.queue_free()
