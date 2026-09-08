extends Node2D


@export var ring_scene: PackedScene

func _ready() -> void:
	var ring: VisualRing = ring_scene.instantiate()
	ring.max_radius = 500.0
	ring.duration = 1.0
	ring.trigger_times = 15
	ring.trigger_interval = 0.3
	ring.wave_triggered.connect(func() -> void:
		KLogger.info("wave triggered!!!!")
	)
	ring.position = get_viewport_rect().size * 0.5
	add_child(ring)
