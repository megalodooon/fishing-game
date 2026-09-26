extends RefCounted
class_name PixelEllipse

# Pixel-art ellipses centered on a pixel. A radius is a whole number of pixels
# on each axis, so an ellipse is always (radius * 2 + 1) pixels wide and tall.
# Shapes are cached per radius, since they are drawn every animation frame.

const PAD : float = 0.25

#------------------------#
static var outlines : Dictionary = {}
static var fills : Dictionary = {}
#------------------------#


# The 1 pixel thin outline: connected corner to corner with no doubled pixels
# at the steps, like a hand drawn ellipse. Each point is the top left corner of
# one pixel, relative to the center pixel's center, ordered around the ellipse.
static func outline(radius : Vector2i) -> PackedVector2Array:
	if outlines.has(radius):
		return outlines[radius]
	var cells : Dictionary = {}
	for x in radius.x + 1:
		var high : int = column_height(radius, x)
		var low : int = mini(high, column_height(radius, x + 1) + 1) if x < radius.x else 0
		for y in range(low, high + 1):
			for cell in [Vector2i(x, y), Vector2i(-x, y), Vector2i(x, -y), Vector2i(-x, -y)]:
				cells[cell] = true
	var ordered : Array = cells.keys()
	ordered.sort_custom(func(a : Vector2i, b : Vector2i) -> bool: return Vector2(a).angle() < Vector2(b).angle())
	var corners : PackedVector2Array = PackedVector2Array()
	for cell : Vector2i in ordered:
		if is_doubled(cells, cell):
			cells.erase(cell)
		else:
			corners.append(Vector2(cell) - Vector2(0.5, 0.5))
	outlines[radius] = corners
	return corners

# The filled ellipse as one rect per row of pixels.
static func rows(radius : Vector2i) -> Array[Rect2]:
	if fills.has(radius):
		return fills[radius]
	var result : Array[Rect2] = []
	for y in range(-radius.y, radius.y + 1):
		var half : int = column_height(Vector2i(radius.y, radius.x), absi(y))
		result.append(Rect2(-half - 0.5, y - 0.5, half * 2 + 1, 1.0))
	fills[radius] = result
	return result

# A pixel at the bend of an L shaped step, which the line doesn't need because
# its two neighbors already touch corner to corner.
static func is_doubled(cells : Dictionary, cell : Vector2i) -> bool:
	for side in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if cells.has(cell + Vector2i(side.x, 0)) and cells.has(cell + Vector2i(0, side.y)):
			return true
	return false

# How far the ellipse reaches from the middle row in column x: the pixel
# centers inside an ellipse a quarter pixel larger than the radius. Any larger
# and small ellipses turn boxy, any smaller and the ends turn into points.
static func column_height(radius : Vector2i, x : int) -> int:
	var across : float = x / (radius.x + PAD)
	return floori((radius.y + PAD) * sqrt(maxf(1.0 - across * across, 0.0)))
