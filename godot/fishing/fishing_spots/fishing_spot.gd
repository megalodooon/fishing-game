@tool
extends Node2D
class_name FishingSpot

const RING_START : float = 1.5
const BUBBLE_FRAMES : int = 3

#------------------------#
@export var radius : float = 10.0
@export var lifetime : Vector2 = Vector2(20.0, 30.0)
@export var appearTime : float = 1.0
@export var disappearTime : float = 1.0
@export var resizeSpeed : float = 4.0

@export_group("Look")
@export_range(0.1, 1.0) var squash : float = 0.55
@export var frameRate : float = 12.0
@export var ringColors : PackedColorArray = PackedColorArray([Color(0.9, 0.99, 1.0, 1.0), Color(0.86, 0.97, 1.0, 0.72), Color(0.86, 0.97, 1.0, 0.45)])
@export var ringSpeed : float = 4.0
@export var ringInterval : Vector2 = Vector2(1.0, 1.2)
@export_range(0.0, 1.0) var ringOpen : float = 0.45
@export_range(0.0, 1.0) var farSideAge : float = 0.25
@export var shadowColor : Color = Color(0.0, 0.06, 0.16, 0.17)
@export_range(0.0, 1.0) var shadowSize : float = 0.55
@export var bubbleColor : Color = Color(0.92, 0.99, 1.0, 1.0)
@export var bubbleInterval : Vector2 = Vector2(0.4, 1.2)
@export_range(0.0, 1.0) var bubbleSpread : float = 0.35

var sizeScale : float = 1.0
var lifetimeScale : float = 1.0
var size : float = 0.0
var presence : float = 0.0
var leaving : bool = false
var age : float = 0.0
var life : float = 0.0
var rings : PackedFloat32Array = PackedFloat32Array()
var ringTimer : float = 0.0
var bubbles : PackedVector3Array = PackedVector3Array()
var bubbleTimer : float = 0.0
var frame : int = -1
var framePhase : float = 0.0
var random : RandomNumberGenerator = RandomNumberGenerator.new()
#------------------------#


func _ready() -> void:
	random.seed = randi()
	size = target_size()
	life = random.randf_range(lifetime.x, lifetime.y)
	framePhase = random.randf()
	if Engine.is_editor_hint():
		presence = 1.0

func _process(delta : float) -> void:
	age += delta
	size = lerpf(size, target_size(), 1.0 - exp(-resizeSpeed * delta))
	if not Engine.is_editor_hint():
		if not leaving and age >= appearTime + life * lifetimeScale:
			disappear()
		presence = move_toward(presence, 0.0 if leaving else 1.0, delta / maxf(disappearTime if leaving else appearTime, 0.001))
		if leaving and presence <= 0.0 and rings.is_empty():
			queue_free()
			return
	update_rings(delta)
	bubbleTimer -= delta
	var tick : int = floori(age * frameRate + framePhase)
	if tick != frame:
		frame = tick
		update_bubbles()
		queue_redraw()

func target_size() -> float:
	return radius * (1.0 if Engine.is_editor_hint() else sizeScale)

func disappear() -> void:
	leaving = true

func update_rings(delta : float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i] += ringSpeed * delta
		if rings[i] >= size:
			rings.remove_at(i)
	ringTimer -= delta
	if ringTimer <= 0.0:
		ringTimer += maxf(random.randf_range(ringInterval.x, ringInterval.y), 0.05)
		if not leaving:
			rings.append(RING_START)

func update_bubbles() -> void:
	for i in range(bubbles.size() - 1, -1, -1):
		if frame - int(bubbles[i].z) >= BUBBLE_FRAMES:
			bubbles.remove_at(i)
	if bubbleTimer <= 0.0 and not leaving:
		bubbleTimer = random.randf_range(bubbleInterval.x, bubbleInterval.y)
		var offset : Vector2 = Vector2.from_angle(random.randf() * TAU) * sqrt(random.randf()) * size * bubbleSpread
		bubbles.append(Vector3(roundf(offset.x), roundf(offset.y * squash), frame))

func _draw() -> void:
	if size <= 0.0 or ringColors.is_empty():
		return
	var shade : float = size * shadowSize * presence
	for reach : float in [shade, shade * 0.6]:
		if reach >= 0.5:
			for row in PixelEllipse.rows(pixel_radius(reach)):
				draw_rect(row, shadowColor)
	for ring in rings:
		var near : float = clampf(ring / size, 0.0, 1.0)
		var far : float = minf(near + farSideAge, 1.0)
		var shape : Vector2i = pixel_radius(ring)
		for corner in PixelEllipse.outline(shape):
			var progress : float = far if corner.y < -0.5 else near
			var gap : float = clampf((progress - ringOpen) / maxf(1.0 - ringOpen, 0.001), 0.0, 1.0) * PI / 4.0
			if gap <= 0.0 or diagonal_closeness(corner + Vector2(0.5, 0.5), shape) > gap:
				draw_rect(Rect2(corner, Vector2.ONE), ringColors[mini(floori(progress * ringColors.size()), ringColors.size() - 1)])
	for bubble in bubbles:
		var step : int = frame - int(bubble.z)
		draw_rect(Rect2(bubble.x - 0.5, bubble.y - 0.5, 1.0, 1.0), bubbleColor if step == 1 else Color(bubbleColor, bubbleColor.a * 0.5))

# How far a pixel on an outline is from the nearest of the top, bottom, left
# and right points, as an angle: 0 there, up to PI / 4 on the diagonals.
func diagonal_closeness(pixel : Vector2, shape : Vector2i) -> float:
	var angle : float = absf(atan2(pixel.y / (shape.y + PixelEllipse.PAD), pixel.x / (shape.x + PixelEllipse.PAD)))
	return absf(fposmod(angle + PI / 4.0, PI / 2.0) - PI / 4.0)

func pixel_radius(value : float) -> Vector2i:
	return Vector2i(roundi(value), roundi(value * squash))
