@tool
extends CanvasLayer
class_name DayNightCycle

signal time_changed(hour : int, minute : int)

const MAX_LIGHTS : int = 16
const WARM_UP_FRAMES : int = 2

#------------------------#
@export var dayLength : float = 720.0
@export_range(0.0, 24.0, 0.05) var startTime : float = 8.0:
	set(value):
		startTime = value
		if Engine.is_editor_hint():
			time = value
@export var paused : bool = false
@export_range(1, 60) var minuteStep : int = 5
@export var colors : Gradient
@export var glowTexture : Texture2D

var time : float = 8.0
var day : int = 1
var hour : int = -1
var minute : int = -1
var tint : Color = Color.WHITE
var darkness : float = 0.0
var overlay : ColorRect
var glows : Node2D
var lights : PackedVector4Array = PackedVector4Array()
var lightColors : PackedVector4Array = PackedVector4Array()
var glowRects : Array[Rect2] = []
var glowColors : PackedColorArray = PackedColorArray()
var frames : int = 0
var clock : float = 0.0
#------------------------#


func _ready() -> void:
	time = startTime
	lights.resize(MAX_LIGHTS)
	lightColors.resize(MAX_LIGHTS)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = ShaderMaterial.new()
	overlay.material.shader = preload("res://components/day_night/day_night.gdshader")
	glows = Node2D.new()
	glows.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glows.material = CanvasItemMaterial.new()
	glows.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glows.draw.connect(draw_glows)
	add_child(overlay, false, Node.INTERNAL_MODE_FRONT)
	add_child(glows, false, Node.INTERNAL_MODE_FRONT)

func _process(delta : float) -> void:
	if not Engine.is_editor_hint() and not paused and dayLength > 0.0:
		time += delta * 24.0 / dayLength
		if time >= 24.0:
			time = fmod(time, 24.0)
			day += 1
	frames += 1
	clock += delta
	update_clock()
	update_light()

func update_clock() -> void:
	var total : int = floori(time * 60.0 / minuteStep) * minuteStep
	@warning_ignore("integer_division")
	var newHour : int = total / 60
	if newHour != hour or total % 60 != minute:
		hour = newHour
		minute = total % 60
		time_changed.emit(hour, minute)

func update_light() -> void:
	tint = colors.sample(time / 24.0) if colors else Color.WHITE
	darkness = 1.0 - tint.get_luminance()
	if not overlay:
		return
	overlay.visible = frames <= WARM_UP_FRAMES or minf(tint.r, minf(tint.g, tint.b)) < 0.998
	glows.visible = overlay.visible
	if not overlay.visible:
		return
	var view : Transform2D = Transform2D.IDENTITY if Engine.is_editor_hint() else get_viewport().get_canvas_transform()
	var zoom : Vector2 = view.get_scale().abs()
	var count : int = 0
	glowRects.clear()
	glowColors.clear()
	for light : NightLight in get_tree().get_nodes_in_group(NightLight.GROUP):
		var strength : float = light.strength(darkness, clock)
		if count >= MAX_LIGHTS or strength <= 0.0 or not light.is_visible_in_tree():
			continue
		var center : Vector2 = view * (light.global_position + Vector2(0.0, light.height))
		lights[count] = Vector4(center.x, center.y, maxf(light.radius * zoom.x, 0.01), maxf(light.radius * light.squash * zoom.y, 0.01))
		lightColors[count] = Vector4(light.color.r * strength, light.color.g * strength, light.color.b * strength, light.falloff)
		count += 1
		if glowTexture and light.glow > 0.0:
			var size : Vector2 = zoom * light.glowRadius * 2.0
			glowRects.append(Rect2(view * light.global_position - size / 2.0, size))
			glowColors.append(Color(light.color, minf(light.glow * strength, 1.0)))
	var rid : RID = overlay.material.get_rid()
	RenderingServer.material_set_param(rid, "ambient", Vector3(tint.r, tint.g, tint.b))
	RenderingServer.material_set_param(rid, "lights", lights)
	RenderingServer.material_set_param(rid, "light_colors", lightColors)
	RenderingServer.material_set_param(rid, "light_count", count)
	glows.queue_redraw()

func draw_glows() -> void:
	for i in glowRects.size():
		glows.draw_texture_rect(glowTexture, glowRects[i], false, glowColors[i])

func set_time(hours : float) -> void:
	time = fposmod(hours, 24.0)
	update_clock()
	update_light()
