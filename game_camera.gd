class_name GameCamera
extends Camera2D

const NORMAL_SHAKE_STRENGTH: float = 3.0
const STRONG_SHAKE_STRENGTH: float = 30.0
const NORMAL_SHAKE_TIME: float = 0.2
const STRONG_SHAKE_TIME: float = 0.5

static var instance: GameCamera

@export var noise: FastNoiseLite

var progress: float = 0.0
var sample_x: float = 0.0
var sample_y: float = 0.0
var sample_step: float = 400
var strength: float = 0.0
var strong_shake_running: bool = false
var max_time: float = 0.0
var cur_time: float = 0.0


func _ready() -> void:
	instance = self


func _process(delta: float) -> void:
	if is_zero_approx(progress):
		return
	sample_x += sample_step * delta
	sample_y += sample_step * delta
	progress = (max_time - cur_time) / max_time
	progress = clampf(progress, 0.0, 1.0)
	cur_time += delta
	offset = Vector2(
		noise.get_noise_2d(sample_x, 0.0),
		noise.get_noise_2d(0.0, sample_y)
	) * strength * progress * progress
	if strong_shake_running and is_zero_approx(progress):
		strong_shake_running = false


static func shake(time: float = -1.0, shake_strength: float = -1.0) -> void:
	if not instance or instance.strong_shake_running:
		return
	instance.strength = NORMAL_SHAKE_STRENGTH if shake_strength <= 0.0 else shake_strength
	instance.max_time = NORMAL_SHAKE_TIME if time <= 0.0 else time
	instance.cur_time = 0.0
	instance.progress = 1.0


static func strong_shake(time: float = -1.0, shake_strength: float = -1.0) -> void:
	if not instance:
		return
	instance.strength = STRONG_SHAKE_STRENGTH if shake_strength <= 0.0 else shake_strength
	instance.max_time = STRONG_SHAKE_TIME if time <= 0.0 else time
	instance.cur_time = 0.0
	instance.progress = 1.0
	instance.strong_shake_running = true