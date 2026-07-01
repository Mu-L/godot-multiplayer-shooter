class_name EnemySpawnComponent
extends Node

signal round_changed(round_count: int)
signal round_completed
signal max_round_end
signal bonus_round_started
signal boss_round_started

const MAX_ROUND: int = 10

## 关卡配置表, 数组索引 0-9 对应关卡 1-10
## weights: slime / poppy / stone_poke; spawn_interval 为 Vector2(min, max)
const ROUND_CONFIGS: Array[Dictionary] = [
	# [1] 热身 - 史莱姆专场, 组小(1~2), 低频
	{ "slime": 1.0, "poppy": 0.0, "stone_poke": 0.0, "round_time": 15.0, "hp_scale": 0.6, "dmg_scale": 0.5, "spawn_interval": Vector2(2.5, 3.0), "group_min": 1, "group_max": 2, "is_bonus": false, "is_boss": false },
	# [2] 引入 - 首次气球
	{ "slime": 0.8, "poppy": 0.2, "stone_poke": 0.0, "round_time": 18.0, "hp_scale": 0.7, "dmg_scale": 0.6, "spawn_interval": Vector2(2.5, 3.0), "group_min": 1, "group_max": 3, "is_bonus": false, "is_boss": false },
	# [3] 熟悉 - 混编
	{ "slime": 0.6, "poppy": 0.4, "stone_poke": 0.0, "round_time": 20.0, "hp_scale": 0.9, "dmg_scale": 0.8, "spawn_interval": Vector2(2.5, 3.0), "group_min": 2, "group_max": 4, "is_bonus": false, "is_boss": false },
	# [4] 预压 - 石刺入场, 前半段高峰
	{ "slime": 0.45, "poppy": 0.35, "stone_poke": 0.20, "round_time": 25.0, "hp_scale": 1.0, "dmg_scale": 1.0, "spawn_interval": Vector2(2.5, 3.0), "group_min": 2, "group_max": 5, "is_bonus": false, "is_boss": false },
	# [5] 奖励关 - 无敌人, 拾取物
	{ "is_bonus": true, "round_time": 20.0, "pickup_count": 6 },
	# [6] 二阶启动 - 后半段起手
	{ "slime": 0.35, "poppy": 0.40, "stone_poke": 0.25, "round_time": 25.0, "hp_scale": 1.1, "dmg_scale": 1.0, "spawn_interval": Vector2(2.0, 3.0), "group_min": 3, "group_max": 5, "is_bonus": false, "is_boss": false },
	# [7] 坦克潮 - 石刺主导
	{ "slime": 0.25, "poppy": 0.30, "stone_poke": 0.45, "round_time": 30.0, "hp_scale": 1.3, "dmg_scale": 1.1, "spawn_interval": Vector2(2.0, 3.0), "group_min": 3, "group_max": 6, "is_bonus": false, "is_boss": false },
	# [8] 气球暴 - 密集爆炸
	{ "slime": 0.10, "poppy": 0.80, "stone_poke": 0.10, "round_time": 28.0, "hp_scale": 1.0, "dmg_scale": 1.2, "spawn_interval": Vector2(2.0, 3.0), "group_min": 4, "group_max": 7, "is_bonus": false, "is_boss": false },
	# [9] 终极测试 - 全方位高压
	{ "slime": 0.30, "poppy": 0.30, "stone_poke": 0.40, "round_time": 35.0, "hp_scale": 1.6, "dmg_scale": 1.4, "spawn_interval": Vector2(2.0, 3.0), "group_min": 4, "group_max": 8, "is_bonus": false, "is_boss": false },
	# [10] BOSS - 多阶段
	{ "is_boss": true, "round_time": 45.0 },
]

const PICKUP_AREA_SCENE := preload("res://entities/pickup/pickup_area.tscn")
const PICKUP_AREA := preload("res://entities/pickup/pickup_area.gd")

@export var spawn_root: Node2D
@export var spawn_rect: ReferenceRect
@export var uprade_component: UpgradeComponent
@export var multiplayer_spawner: MultiplayerSpawner

var round_count: int = 0:
	get:
		return round_count
	set(value):
		round_count = value
		round_changed.emit(value)
var enemy_count: int = 0
var enemy_configs: Array[EnemyResource] = []

## 运行时由 _start_round 从 ROUND_CONFIGS 读取
var _current_round_config: Dictionary = {}
var current_group_min: int = 1
var current_group_max: int = 2
var current_hp_scale: float = 1.0
var current_dmg_scale: float = 1.0
var round_min_spawn_interval: float = 2.0
var round_max_spawn_interval: float = 2.0

var _is_bonus_round: bool = false
var _is_boss_round: bool = false
var _bonus_pickups_remaining: int = 0

@onready var spawn_timer: Timer = $SpawnTimer
@onready var round_timer: Timer = $RoundTimer

func _ready() -> void:
	_load_enemy_configs()
	_register_spawnable_scenes()
	if is_multiplayer_authority():
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		round_timer.timeout.connect(_on_round_timer_timeout)
		GameEvents.enemy_died.connect(_on_enemy_died)
		uprade_component.upgrade_finished.connect(_on_upgrade_finished)


func start() -> void:
	if is_multiplayer_authority():
		_start_round()


func _start_round() -> void:
	round_count += 1
	print("Round %s start" % round_count)
	if round_count < 1 or round_count > ROUND_CONFIGS.size():
		push_error("[EnemySpawn] round_count out of range: %s" % round_count)
		return
	var config: Dictionary = ROUND_CONFIGS[round_count - 1]
	_current_round_config = config
	if config.get("is_bonus", false):
		_start_bonus_round(config)
		return
	if config.get("is_boss", false):
		_start_boss_round(config)
		return
	# 普通关
	var interval: Vector2 = config["spawn_interval"]
	round_min_spawn_interval = interval.x
	round_max_spawn_interval = interval.y
	current_group_min = config.get("group_min", 1)
	current_group_max = config.get("group_max", 2)
	current_hp_scale = config["hp_scale"]
	current_dmg_scale = config["dmg_scale"]
	_is_bonus_round = false
	_is_boss_round = false
	round_timer.start(config["round_time"])
	spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
	synchronize()


func _start_bonus_round(config: Dictionary) -> void:
	_is_bonus_round = true
	_is_boss_round = false
	_bonus_pickups_remaining = 0
	var pickup_count: int = config.get("pickup_count", 6)
	round_timer.start(config["round_time"])
	spawn_timer.stop()
	for i in range(pickup_count):
		var ptype := _roll_pickup_type()
		var pos := _get_random_position()
		_spawn_pickup(ptype, pos)
	synchronize()
	bonus_round_started.emit()
	print("[EnemySpawn] Bonus Round %s started, %s pickups" % [round_count, pickup_count])


func _start_boss_round(config: Dictionary) -> void:
	_is_boss_round = true
	_is_bonus_round = false
	round_timer.start(config["round_time"])
	spawn_timer.stop()
	# TODO (Phase 4): spawn boss via boss_scene from enemy_config.csv
	synchronize()
	boss_round_started.emit()
	print("[EnemySpawn] Boss Round %s started" % round_count)


func _roll_pickup_type() -> int:
	var roll := randf()
	if roll < 0.30:
		return PICKUP_AREA.HEALING_POTION
	elif roll < 0.60:
		return PICKUP_AREA.MEDKIT
	else:
		return PICKUP_AREA.UPGRADE


func _spawn_pickup(pickup_type: int, pos: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	var pickup := PICKUP_AREA_SCENE.instantiate()
	pickup.pickup_type = pickup_type
	pickup.global_position = pos
	pickup.tree_exited.connect(_on_pickup_removed)
	spawn_root.add_child(pickup, true)
	_bonus_pickups_remaining += 1


func _on_pickup_removed() -> void:
	_bonus_pickups_remaining -= 1


func _check_round_completed() -> void:
	if _is_bonus_round:
		# 奖励关时间到即完成
		if round_timer.is_stopped():
			print("Bonus Round %s completed!" % round_count)
			_is_bonus_round = false
			if round_count < MAX_ROUND:
				round_completed.emit()
			else:
				max_round_end.emit()
		return
	if _is_boss_round:
		# BOSS 关: 时间到且敌人清空 → 完成
		if round_timer.is_stopped() and enemy_count == 0:
			_is_boss_round = false
			if round_count < MAX_ROUND:
				round_completed.emit()
			else:
				max_round_end.emit()
		return
	# 普通关
	if !round_timer.is_stopped():
		return
	if enemy_count == 0:
		print("Round %s completed!" % round_count)
		if round_count < MAX_ROUND:
			round_completed.emit()
		else:
			await get_tree().create_timer(1.0).timeout
			max_round_end.emit()


func _get_random_position() -> Vector2:
	var pos := Vector2(
		randf_range(0, spawn_rect.size.x),
		randf_range(0, spawn_rect.size.y),
	)
	pos += spawn_rect.global_position
	return pos


func _load_enemy_configs() -> void:
	enemy_configs.clear()
	for res: EnemyResource in CSVResourceCache.get_all_enemies():
		if res.scene == null:
			push_warning("[EnemySpawn] Enemy config %s has no scene" % res.id)
			continue
		enemy_configs.append(res)


func _register_spawnable_scenes() -> void:
	var registered_scenes: Dictionary[String, bool] = {}
	for config: EnemyResource in enemy_configs:
		var scene_path := config.scene.resource_path
		if scene_path.is_empty() or registered_scenes.has(scene_path):
			continue
		multiplayer_spawner.add_spawnable_scene(scene_path)
		registered_scenes[scene_path] = true
	# 拾取物场景也注册到 spawner, 便于网络同步生成
	var pickup_path := PICKUP_AREA_SCENE.resource_path
	if not registered_scenes.has(pickup_path):
		multiplayer_spawner.add_spawnable_scene(pickup_path)
		registered_scenes[pickup_path] = true


## 按权重表选择敌人类型. weights 字典: { EnemyResource.id: float }
## 使用加权数组 + pick_random 实现, 便于 GDScript 风格
func _select_enemy_config(weights: Dictionary) -> EnemyResource:
	if enemy_configs.is_empty():
		return null
	var weighted_list: Array[EnemyResource] = []
	for config in enemy_configs:
		var w: float = weights.get(config.id, 0.0)
		if w <= 0.0:
			continue
		var count: int = maxi(1, int(w * 10))
		for i in range(count):
			weighted_list.append(config)
	if weighted_list.is_empty():
		return enemy_configs.pick_random()
	return weighted_list.pick_random()


func get_round_time_left() -> float:
	return round_timer.time_left


func synchronize(peer_id: int = -1) -> void:
	if not is_multiplayer_authority():
		return
	var data = {
		"round_count": round_count,
		"round_timer_time_left": round_timer.time_left,
		"round_timer_running": not round_timer.is_stopped()
	}
	if peer_id < 0:
		_synchronize.rpc(data)
	elif peer_id > 1:
		_synchronize.rpc_id(peer_id, data)


@rpc("authority", "call_remote", "reliable")
func _synchronize(data: Dictionary) -> void:
	round_count = data.round_count
	var wait_time: float = data.round_timer_time_left
	if wait_time > 0:
		round_timer.wait_time = wait_time
	if data.round_timer_running:
		round_timer.start()


## 配置化群组刷怪: 每次在 [group_min, group_max] 随机选组大小,
## 多人每人 +1, 同组同型, 独立计算属性
func _spawn_enemy() -> void:
	if not is_multiplayer_authority():
		return
	if _current_round_config.is_empty() or _current_round_config.get("is_bonus", false) or _current_round_config.get("is_boss", false):
		return
	var group_size: int = randi_range(current_group_min, current_group_max)
	var peers := Tools.get_game_peers_count()
	if peers > 1:
		group_size += (peers - 1)

	for i in range(group_size):
		# 选取敌人类型
		var config := _select_enemy_config(_current_round_config)
		if config == null:
			push_error("[EnemySpawn] No enemy config selected")
			spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
			return
		# 生成对应类型敌人
		var enemy := config.scene.instantiate() as Node2D
		spawn_root.add_child(enemy, true)
		if enemy.has_method("apply_enemy_config"):
			enemy.apply_enemy_config(config, current_hp_scale, current_dmg_scale)
		enemy.global_position = _get_random_position()
		enemy_count += 1
	spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))


func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()


func _on_round_timer_timeout() -> void:
	print("Round %s end" % round_count)
	spawn_timer.stop()
	_check_round_completed()


func _on_enemy_died() -> void:
	enemy_count -= 1
	_check_round_completed()


func _on_upgrade_finished() -> void:
	_start_round()
