class_name HitboxComponent
extends Area2D

signal hit(hurtbox: HurtboxComponent)

var damage: float = 1
var is_single_hit: bool = false
var is_single_hit_per_hurtbox: bool = false
var hit_count: int = 0
var hit_hurtboxes: Array[HurtboxComponent] = []


func _ready() -> void:
	if not is_multiplayer_authority():
		process_mode = Node.PROCESS_MODE_DISABLED


func has_hit_hurtbox(hurtbox: HurtboxComponent) -> bool:
	return hurtbox in hit_hurtboxes


func reset_hit_records() -> void:
	hit_count = 0
	hit_hurtboxes.clear()


func register_hit(hurtbox: HurtboxComponent) -> void:
	hit_count += 1
	if hurtbox not in hit_hurtboxes:
		hit_hurtboxes.append(hurtbox)
	hit.emit(hurtbox)
