class_name OptionMenu
extends Control

@onready var sfx_minus_button: Button = %SFXMinusButton
@onready var sfx_progress_bar: ProgressBar = %SFXProgressBar
@onready var sfx_plus_button: Button = %SFXPlusButton
@onready var music_minus_button: Button = %MusicMinusButton
@onready var music_progress_bar: ProgressBar = %MusicProgressBar
@onready var music_plus_button: Button = %MusicPlusButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	sfx_progress_bar.value = _get_bus_volume("sfx")
	music_progress_bar.value = _get_bus_volume("music")
	sfx_minus_button.pressed.connect(_on_volume_change.bind("sfx", true))
	sfx_plus_button.pressed.connect(_on_volume_change.bind("sfx", false))
	music_minus_button.pressed.connect(_on_volume_change.bind("music", true))
	music_plus_button.pressed.connect(_on_volume_change.bind("music", false))
	close_button.pressed.connect(_on_close_button_pressed)
	var btns: Array[Button] = [
		sfx_minus_button,
		sfx_plus_button,
		music_minus_button,
		music_plus_button,
	]
	SoundManager.register_hover(btns)
	SoundManager.register_click(btns)


func _get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_linear(index)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(index, volume)


func _on_volume_change(bus_name: String, minus: bool) -> void:
	var volume := _get_bus_volume(bus_name)
	var change := -0.1 if minus else 0.1
	volume = clampf(volume + change, 0, 1)
	_set_bus_volume(bus_name, volume)
	match bus_name:
		"sfx": sfx_progress_bar.value = volume
		_: music_progress_bar.value = volume


func _on_close_button_pressed() -> void:
	queue_free()
