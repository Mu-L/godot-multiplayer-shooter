class_name ShieldGhostComponent
extends Sprite2D

var tween: Tween

## 播放护盾虚影动画：intensity 从高到低消散
func play_shield_animation() -> void:
	if (not tween == null) and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(material, "shader_parameter/intensity", 0.0, 0.5)\
		.from(0.9)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_LINEAR)
