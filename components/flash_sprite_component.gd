class_name FlashSpriteComponent
extends Sprite2D

var tween: Tween

func play_flash_animation() -> void:
	if (not tween == null) and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(material, "shader_parameter/percent", 0.0, 0.2)\
		.from(0.9)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_LINEAR)
