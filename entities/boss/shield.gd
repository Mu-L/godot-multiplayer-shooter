extends Area2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not area is HitboxComponent:
		return
	var hitbox := area as HitboxComponent
	if hitbox.owner is Bullet:
		# TODO 音效
		hitbox.owner.queue_free()
