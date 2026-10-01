extends Control
class_name WeatherOverlay

# Rain and fog drawn over the world, under the day/night tint so the night
# darkens them too. Rain is thin slanted streaks with little splash rings and
# a cool tint, fog is a few big soft blobs drifting over a light haze. Both
# fade in and out, and nothing is drawn in clear weather.

#------------------------#
@export var fadeTime : float = 3.0
@export var drops : int = 70
@export var dropSpeed : Vector2 = Vector2(150.0, 190.0)
@export var dropLength : Vector2 = Vector2(5.0, 9.0)
@export var wind : float = -0.28
@export var dropWidth : float = 0.22
@export var dropColor : Color = Color(0.78, 0.88, 1.0, 0.42)
@export var splashColor : Color = Color(0.85, 0.93, 1.0, 0.5)
@export var rainTint : Color = Color(0.3, 0.4, 0.55, 0.2)
@export var blobs : int = 7
@export var blobSize : Vector2 = Vector2(90.0, 150.0)
@export var blobSpeed : Vector2 = Vector2(2.0, 6.0)
@export var fogColor : Color = Color(0.86, 0.9, 0.95, 0.42)
@export var hazeColor : Color = Color(0.8, 0.85, 0.9, 0.22)

var rain : float = 0.0
var fog : float = 0.0
var rainGoal : float = 0.0
var fogGoal : float = 0.0
var dropList : Array[Vector4] = []
var splashes : Array[Vector3] = []
var blobList : Array[Vector4] = []
var soft : GradientTexture2D
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR
	set_anchors_preset(PRESET_FULL_RECT)
	var gradient : Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	soft = GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64

func set_state(state : int, instant : bool) -> void:
	rainGoal = 1.0 if state == Weather.State.RAIN else 0.0
	fogGoal = 1.0 if state == Weather.State.FOG else 0.0
	if instant:
		rain = rainGoal
		fog = fogGoal
	if rainGoal > 0.0 and dropList.is_empty():
		for i in drops:
			dropList.append(new_drop(true))
	if fogGoal > 0.0 and blobList.is_empty():
		for i in blobs:
			blobList.append(Vector4(randf() * area().x, randf() * area().y, randf_range(blobSize.x, blobSize.y), randf_range(blobSpeed.x, blobSpeed.y)))

func area() -> Vector2:
	return get_viewport_rect().size

func new_drop(anywhere : bool) -> Vector4:
	var screen : Vector2 = area()
	var y : float = randf() * screen.y if anywhere else -randf() * 20.0
	return Vector4(randf_range(-10.0, screen.x + 30.0), y, randf_range(dropSpeed.x, dropSpeed.y), randf_range(dropLength.x, dropLength.y))

func _process(delta : float) -> void:
	# No rain or fog inside buildings.
	var island : Island = Island.current(get_tree())
	visible = not (island and island.interior)
	if not visible:
		return
	var step : float = delta / fadeTime
	rain = move_toward(rain, rainGoal, step)
	fog = move_toward(fog, fogGoal, step)
	if rain <= 0.0 and fog <= 0.0:
		if not dropList.is_empty() or not blobList.is_empty():
			dropList.clear()
			blobList.clear()
			splashes.clear()
			queue_redraw()
		return
	var screen : Vector2 = area()
	for i in dropList.size():
		var drop : Vector4 = dropList[i]
		drop.y += drop.z * delta
		drop.x += drop.z * wind * delta
		if drop.y > screen.y + 10.0 or randf() < delta * 0.9:
			if drop.y > 0.0 and splashes.size() < 24:
				splashes.append(Vector3(drop.x, drop.y, 0.0))
			drop = new_drop(false)
		dropList[i] = drop
	for i in range(splashes.size() - 1, -1, -1):
		splashes[i].z += delta
		if splashes[i].z > 0.35:
			splashes.remove_at(i)
	for i in blobList.size():
		var blob : Vector4 = blobList[i]
		blob.x += blob.w * delta
		if blob.x - blob.z > screen.x:
			blob.x = -blob.z
			blob.y = randf() * screen.y
		blobList[i] = blob
	queue_redraw()

func _draw() -> void:
	var screen : Rect2 = Rect2(Vector2.ZERO, area())
	if fog > 0.0:
		draw_rect(screen, Color(hazeColor, hazeColor.a * fog))
		for blob in blobList:
			var box : Vector2 = Vector2(blob.z, blob.z * 0.55)
			draw_texture_rect(soft, Rect2(Vector2(blob.x, blob.y) - box * 0.5, box), false, Color(fogColor, fogColor.a * fog))
	if rain > 0.0:
		draw_rect(screen, Color(rainTint, rainTint.a * rain))
		var color : Color = Color(dropColor, dropColor.a * rain)
		for drop in dropList:
			var head : Vector2 = Vector2(drop.x, drop.y)
			draw_line(head, head - Vector2(wind, 1.0).normalized() * drop.w, color, dropWidth, true)
		for splash in splashes:
			var t : float = splash.z / 0.35
			var radius : float = 0.6 + t * 2.4
			draw_set_transform(Vector2(splash.x, splash.y), 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, Color(splashColor, splashColor.a * (1.0 - t) * rain), dropWidth, true)
		draw_set_transform(Vector2.ZERO)
