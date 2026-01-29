extends Node2D
class_name ResourceSpawner

@export var tilemap_path: NodePath
@export var container_path: NodePath

@export var tree_scene: PackedScene
@export var rock_scene: PackedScene

@export var trees_per_day: int = 5
@export var rocks_per_day: int = 5

# Какой слой TileMap считать "землёй"
@export var tile_layer_idx: int = 0

# Какой physics-layer в TileSet содержит коллизию тайла (обычно 0)
@export var tileset_physics_layer: int = 0

# Смещение объекта над поверхностью
@export var spawn_offset_y: float = 10.0

# Минимальная дистанция между точками спавна
@export var min_distance: float = 24.0

# Ограничение попыток на один объект
@export var attempts_per_item: int = 40

var _last_spawned_day: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _surface_cells: Array[Vector2i] = []

func _ready() -> void:
	_rng.randomize()
	Signals.day_time.connect(Callable(self, "_on_time_changed"))

	# ВАЖНО: отложить инициализацию на кадр, чтобы TileMap/коллизии/used_rect точно были готовы
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	var tm: TileMap = _get_tilemap()
	if tm != null:
		_rebuild_surface_cells(tm)

	_spawn_for_day(1)

func _on_time_changed(state: int, day_count: int) -> void:
	# MORNING = 0 (см. level.gd)
	if state != 0:
		return
	if day_count == _last_spawned_day:
		return
	_spawn_for_day(day_count)

func _spawn_for_day(day_count: int) -> void:
	_last_spawned_day = day_count

	for _i in range(trees_per_day):
		_spawn_one(tree_scene)
	for _i in range(rocks_per_day):
		_spawn_one(rock_scene)

func _spawn_one(scene: PackedScene) -> void:
	if scene == null:
		return

	var tm: TileMap = _get_tilemap()
	if tm == null:
		return

	var container: Node = _get_container()
	if container == null:
		# fallback: складывать рядом с TileMap, если контейнер не задан
		container = tm.get_parent()
		if container == null:
			container = self

	if _surface_cells.is_empty():
		_rebuild_surface_cells(tm)
	if _surface_cells.is_empty():
		# Нет ни одной "поверхности" (тайлов с коллизией)
		return

	var tile_size: Vector2 = Vector2(16, 16)
	if tm.tile_set != null:
		tile_size = tm.tile_set.tile_size

	for _try in range(attempts_per_item):
		var idx: int = _rng.randi_range(0, _surface_cells.size() - 1)
		var cell: Vector2i = _surface_cells[idx]

		var p: Vector2 = _cell_to_spawn_pos(tm, cell, tile_size)

		if _too_close(container, p):
			continue

		var obj: Node = scene.instantiate()

		# ВАЖНО: объект ещё не в дереве и не имеет родителя.
		# Если присвоить global_position ДО add_child, позиция станет "локальной",
		# а после добавления к контейнеру будет смещена трансформом контейнера.
		# Поэтому выставляется локальная позиция относительно container (если это Node2D).
		if obj is Node2D:
			if container is Node2D:
				(obj as Node2D).position = (container as Node2D).to_local(p)
			else:
				(obj as Node2D).global_position = p

		# call_deferred безопаснее, если спавн идёт из сигналов/physics
		container.call_deferred("add_child", obj)
		return

func _cell_to_spawn_pos(tm: TileMap, cell: Vector2i, tile_size: Vector2) -> Vector2:
	# map_to_local даёт позицию клетки в локальных координатах TileMap (обычно центр клетки)
	var local_center: Vector2 = tm.map_to_local(cell)
	var g: Vector2 = tm.to_global(local_center)

	# ставить над верхом тайла
	g.y -= (tile_size.y * 0.5 + spawn_offset_y)

	# лёгкий разброс по X внутри тайла (чтобы не было ровной сетки)
	g.x += _rng.randf_range(-tile_size.x * 0.35, tile_size.x * 0.35)

	return g

func _rebuild_surface_cells(tm: TileMap) -> void:
	_surface_cells.clear()

	var rect: Rect2i = tm.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var x0: int = rect.position.x
	var x1: int = rect.position.x + rect.size.x
	var y0: int = rect.position.y
	var y1: int = rect.position.y + rect.size.y

	for x in range(x0, x1):
		for y in range(y0, y1):
			var c: Vector2i = Vector2i(x, y)
			if not _is_solid_tile(tm, c):
				continue

			# "поверхность" = твёрдый тайл, над которым нет твёрдого тайла
			var above: Vector2i = Vector2i(x, y - 1)
			if _is_solid_tile(tm, above):
				continue

			_surface_cells.append(c)

func _is_solid_tile(tm: TileMap, coords: Vector2i) -> bool:
	var td: TileData = tm.get_cell_tile_data(tile_layer_idx, coords)
	if td == null:
		return false
	return td.get_collision_polygons_count(tileset_physics_layer) > 0

func _too_close(container: Node, p: Vector2) -> bool:
	for c in container.get_children():
		if c is Node2D:
			var d: float = (c as Node2D).global_position.distance_to(p)
			if d < min_distance:
				return true
	return false

func _get_tilemap() -> TileMap:
	if tilemap_path == NodePath():
		var tm: Node = get_tree().current_scene.find_child("TileMap", true, false)
		if tm is TileMap:
			return tm as TileMap
		return null
	var n: Node = get_node_or_null(tilemap_path)
	return n as TileMap

func _get_container() -> Node:
	if container_path == NodePath():
		return null
	return get_node_or_null(container_path)
