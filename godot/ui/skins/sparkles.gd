extends RefCounted
class_name Sparkles

# Little bursts of pixels for good moments in menus: buying, crafting,
# unlocking. A menu calls burst(), then update() from _process while it
# returns true, and draw() from _draw.

const GRAVITY : float = 40.0

var positions : PackedVector2Array = PackedVector2Array()
var velocities : PackedVector2Array = PackedVector2Array()
var lives : PackedFloat32Array = PackedFloat32Array()
var colors : PackedColorArray = PackedColorArray()


func burst(at : Vector2, color : Color, count : int = 12, speed : float = 28.0) -> void:
	for i in count:
		var angle : float = randf_range(-PI, 0.0) if i % 3 != 0 else randf() * TAU
		positions.append(at)
		velocities.append(Vector2.from_angle(angle) * speed * randf_range(0.4, 1.0))
		lives.append(randf_range(0.35, 0.7))
		colors.append(color.lightened(randf_range(0.0, 0.5)) if i % 2 == 0 else color)

func active() -> bool:
	return not lives.is_empty()

# Moves every bit along. Returns whether any are left.
func update(delta : float) -> bool:
	var i : int = lives.size() - 1
	while i >= 0:
		lives[i] -= delta
		if lives[i] <= 0.0:
			positions.remove_at(i)
			velocities.remove_at(i)
			lives.remove_at(i)
			colors.remove_at(i)
		else:
			velocities[i] = velocities[i] * (1.0 - 3.0 * delta) + Vector2(0.0, GRAVITY * delta)
			positions[i] += velocities[i] * delta
		i -= 1
	return active()

func draw(canvas : CanvasItem) -> void:
	for i in lives.size():
		var size : float = 1.0 if lives[i] > 0.15 else 0.5
		canvas.draw_rect(Rect2(positions[i] - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(colors[i], clampf(lives[i] / 0.2, 0.0, 1.0)))
