# physics_query_manager.gd
# 注册为全局单例: PhysicsQueryManager
extends Node

# 常驻复用对象 (避免单次查询创建 new 产生内存垃圾)
var _shape_query: PhysicsShapeQueryParameters2D
var _ray_query: PhysicsRayQueryParameters2D
var _circle_shape: CircleShape2D
var _rect_shape: RectangleShape2D

func _ready() -> void:
	# 初始化缓存对象
	_shape_query = PhysicsShapeQueryParameters2D.new()
	_ray_query = PhysicsRayQueryParameters2D.new()
	_circle_shape = CircleShape2D.new()
	_rect_shape = RectangleShape2D.new()

# 圆形瞬态范围检测 (单帧判定)
func query_circle(
	world_2d: World2D,
	center: Vector2,
	radius: float,
	collision_mask: int,
	collide_with_areas: bool = true,
	collide_with_bodies: bool = false,
	max_results: int = 32,
	exclude_rids: Array[RID] = []
) -> Array[Dictionary]:
	if not world_2d:
		return []

	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	_circle_shape.radius = radius
	
	# 重置并填充常驻 Query 参数
	_shape_query.shape = _circle_shape
	_shape_query.transform = Transform2D(0.0, center)
	_shape_query.collision_mask = collision_mask
	_shape_query.collide_with_areas = collide_with_areas
	_shape_query.collide_with_bodies = collide_with_bodies
	_shape_query.exclude = exclude_rids
	
	return space_state.intersect_shape(_shape_query, max_results)

# 矩形瞬态范围检测
func query_box(
	world_2d: World2D,
	transform: Transform2D,
	size: Vector2,
	collision_mask: int,
	collide_with_areas: bool = true,
	collide_with_bodies: bool = false,
	max_results: int = 32,
	exclude_rids: Array[RID] = []
) -> Array[Dictionary]:
	if not world_2d:
		return []

	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	_rect_shape.size = size
	
	_shape_query.shape = _rect_shape
	_shape_query.transform = transform
	_shape_query.collision_mask = collision_mask
	_shape_query.collide_with_areas = collide_with_areas
	_shape_query.collide_with_bodies = collide_with_bodies
	_shape_query.exclude = exclude_rids
	
	return space_state.intersect_shape(_shape_query, max_results)
