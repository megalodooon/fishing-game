extends RefCounted
class_name WalkGrid

# Where people can walk on an island, for villagers finding their way: a grid
# over all its rooms, open where there's land and nothing solid (buildings,
# props, fences). Made once when the island loads; paths are asked for only
# when someone sets off, so it costs nothing while they stand around.

const CELL : int = 4

var astar : AStarGrid2D = AStarGrid2D.new()
var origin : Vector2 = Vector2.ZERO
var cells : Vector2i = Vector2i.ZERO


static func build(island : Island) -> WalkGrid:
	var grid : WalkGrid = WalkGrid.new()
	var bounds : Rect2 = Rect2()
	var first : bool = true
	for room in island.rooms:
		bounds = room.rect() if first else bounds.merge(room.rect())
		first = false
	grid.origin = bounds.position
	grid.cells = Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	grid.astar.region = Rect2i(Vector2i.ZERO, grid.cells)
	grid.astar.cell_size = Vector2(CELL, CELL)
	grid.astar.offset = grid.origin + Vector2(CELL, CELL) * 0.5
	grid.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.astar.update()
	for y in grid.cells.y:
		for x in grid.cells.x:
			var at : Vector2 = grid.origin + Vector2(x + 0.5, y + 0.5) * CELL
			if not island.is_land(at):
				grid.astar.set_point_solid(Vector2i(x, y), true)
	# Solid things: every static body's shapes, except people's own.
	for body in island.find_children("*", "StaticBody2D", true, false):
		if body.get_parent() is Npc:
			continue
		for shape in body.find_children("*", "CollisionShape2D", false, false):
			var area : Rect2 = shape_rect(shape as CollisionShape2D)
			if area.size.x <= 0.0:
				continue
			grid.block(area.grow(1.0))
	return grid

static func shape_rect(node : CollisionShape2D) -> Rect2:
	var shape : Shape2D = node.shape
	var center : Vector2 = node.global_position
	if shape is RectangleShape2D:
		var size : Vector2 = (shape as RectangleShape2D).size * node.global_scale.abs()
		return Rect2(center - size * 0.5, size)
	if shape is CircleShape2D:
		var r : float = (shape as CircleShape2D).radius * maxf(node.global_scale.x, node.global_scale.y)
		return Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	if shape is CapsuleShape2D:
		var capsule : CapsuleShape2D = shape
		var size : Vector2 = Vector2(capsule.radius * 2.0, capsule.height) * node.global_scale.abs()
		return Rect2(center - size * 0.5, size)
	return Rect2()

func block(area : Rect2) -> void:
	var from : Vector2i = cell_of(area.position)
	var to : Vector2i = cell_of(area.end)
	for y in range(maxi(from.y, 0), mini(to.y + 1, cells.y)):
		for x in range(maxi(from.x, 0), mini(to.x + 1, cells.x)):
			astar.set_point_solid(Vector2i(x, y), true)

func cell_of(point : Vector2) -> Vector2i:
	return Vector2i(floori((point.x - origin.x) / CELL), floori((point.y - origin.y) / CELL))

func inside(cell : Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells.x and cell.y < cells.y

func open(cell : Vector2i) -> bool:
	return inside(cell) and not astar.is_point_solid(cell)

# The nearest open cell to a point, searching outwards a little.
func nearest_open(point : Vector2) -> Vector2i:
	var start : Vector2i = cell_of(point)
	if open(start):
		return start
	for radius in range(1, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell : Vector2i = start + Vector2i(dx, dy)
				if open(cell):
					return cell
	return Vector2i(-1, -1)

# A walking path in global points from one place to another, or [] when
# there's none. The last point is the exact goal when it's walkable.
func path(from : Vector2, to : Vector2) -> PackedVector2Array:
	var a : Vector2i = nearest_open(from)
	var b : Vector2i = nearest_open(to)
	if not inside(a) or not inside(b):
		return PackedVector2Array()
	var points : PackedVector2Array = astar.get_point_path(a, b)
	if points.is_empty():
		return points
	if open(cell_of(to)):
		points[points.size() - 1] = to
	return simplify(points)

# Drops the points in the middle of straight runs.
static func simplify(points : PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var out : PackedVector2Array = PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var before : Vector2 = (points[i] - points[i - 1]).normalized()
		var after : Vector2 = (points[i + 1] - points[i]).normalized()
		if not before.is_equal_approx(after):
			out.append(points[i])
	out.append(points[points.size() - 1])
	return out
