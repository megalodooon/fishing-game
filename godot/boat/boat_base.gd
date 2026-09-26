extends Node2D
class_name Boat

const CLIP_MARGIN : int = 4
const HOLE_MARGIN : float = 2.0

#------------------------#
@export var visuals : Node2D
@export var cruiseSpeed : float = 10.0
@export var maxSpeed : float = 50.0
@export var speedChangeTime : float = 2.0
@export var stopTime : float = 2.0
@export var startTime : float = 2.0
@export var testAcceleration : float = 60.0
@export var motionEffects : Array[CanvasItem] = []
@export var movingOnly : Array[CanvasItem] = []
@export var deck : Sprite2D
@export var deckFloor : Polygon2D
@export var hull : Array[Sprite2D] = []
@export var deckHeight : float = 17.0
@export var occluders : Array[Sprite2D] = []
@export_range(0.0, 1.0) var occluderFade : float = 0.3
@export var occluderFadeTime : float = 0.25

var upgrades : Array[BoatUpgrade] = []
var speed : float = 0.0
var targetSpeed : float = 0.0
var resumeSpeed : float = 0.0
var speedTween : Tween
var occluderStatic : Dictionary = {}
var occluderAxes : PackedVector4Array = PackedVector4Array()
var occluderOrigins : PackedVector2Array = PackedVector2Array()
var occluderFrame : int = -1
var faded : bool = false
var usedRects : Dictionary = {}
var fadeTween : Tween
var appliedMotion : float = -1.0
var opaqueRect : Variant = null
#------------------------#


func _ready() -> void:
	speed = cruiseSpeed
	targetSpeed = cruiseSpeed
	if visuals:
		for sprite : Sprite2D in visuals.find_children("*", "Sprite2D", true, false):
			if sprite.texture and not sprite is BoatWaterline:
				clip_to_rect(sprite, art_rect(sprite, CLIP_MARGIN))

static func art_rect(sprite : Sprite2D, margin : int) -> Rect2:
	var full : Vector2 = sprite.texture.get_size()
	var used : Rect2 = Rect2(sprite.texture.get_image().get_used_rect().grow(margin)).intersection(Rect2(Vector2.ZERO, full))
	var rect : Rect2 = Rect2(sprite.offset - (full / 2.0 if sprite.centered else Vector2.ZERO) + used.position, used.size)
	for child in sprite.get_children():
		if child is Sprite2D and child.texture:
			rect = rect.merge(child.transform * art_rect(child, margin))
	return rect

static func clip_to_rect(item : CanvasItem, rect : Rect2) -> void:
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), true, rect)
	RenderingServer.canvas_item_set_clip(item.get_canvas_item(), true)
	item.draw.connect(RenderingServer.canvas_item_set_clip.bind(item.get_canvas_item(), true))

static func pixel_aligned(item : CanvasItem) -> bool:
	var xform : Transform2D = item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()
	return xform.x.y == 0.0 and xform.y.x == 0.0 and xform.x.x == xform.y.y and xform.x.x == floorf(xform.x.x) and xform.origin == xform.origin.floor()

static func band_rects(outer : Rect2, hole : Rect2) -> Array[Rect2]:
	var start : Vector2 = hole.position.ceil()
	var end : Vector2 = hole.end.floor()
	if end.x <= start.x or end.y <= start.y:
		return [outer]
	var cut : Rect2 = Rect2(start, end - start).intersection(outer)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [outer]
	return [
		Rect2(outer.position.x, outer.position.y, outer.size.x, cut.position.y - outer.position.y),
		Rect2(outer.position.x, cut.end.y, outer.size.x, outer.end.y - cut.end.y),
		Rect2(outer.position.x, cut.position.y, cut.position.x - outer.position.x, cut.size.y),
		Rect2(cut.end.x, cut.position.y, outer.end.x - cut.end.x, cut.size.y),
	]

func opaque_rect() -> Rect2:
	if opaqueRect == null:
		opaqueRect = find_opaque_rect()
	return opaqueRect

func find_opaque_rect() -> Rect2:
	var waterline : BoatWaterline = deck as BoatWaterline
	var shaded : ShaderMaterial = waterline.material as ShaderMaterial if waterline else null
	if not shaded or not waterline.texture:
		return Rect2()
	var clearance : float = 4.0
	for pair in [["depth", 1.0], ["wave_height", 1.725], ["line_width", 0.5], ["end_rise", 1.0]]:
		var value : Variant = parameter(shaded, pair[0])
		if value == null:
			return Rect2()
		clearance += absf(value) * pair[1]
	var image : Image = waterline.texture.get_image()
	var edgeImage : Image = (waterline.edgeTexture if waterline.edgeTexture else waterline.texture).get_image()
	var width : int = image.get_width()
	var tops : PackedInt32Array = PackedInt32Array()
	var limits : PackedInt32Array = PackedInt32Array()
	var edges : PackedInt32Array = PackedInt32Array()
	for x in width:
		var edge : int = 0
		for y in range(edgeImage.get_height() - 1, -1, -1):
			if edgeImage.get_pixel(x, y).a > 0.0:
				edge = y + 1
				break
		edges.append(edge)
	for x in width:
		var top : int = -1
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.0:
				top = y
				break
		var bottom : int = top
		while top >= 0 and bottom + 1 < image.get_height() and image.get_pixel(x, bottom + 1).a > 0.0:
			bottom += 1
		var edge : int = mini(edges[x], mini(edges[maxi(x - 1, 0)], edges[mini(x + 1, width - 1)]))
		tops.append(top)
		limits.append(mini(bottom + 1, floori(edge - clearance)) if top >= 0 and edge > 0 else -1)
	var best : Rect2i = Rect2i()
	for x0 in width:
		var y0 : int = 0
		var y1 : int = 1 << 30
		for x1 in range(x0, width):
			if limits[x1] <= tops[x1]:
				break
			y0 = maxi(y0, tops[x1])
			y1 = mini(y1, limits[x1])
			if y1 > y0 and (x1 - x0 + 1) * (y1 - y0) > best.get_area():
				best = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0)
	if not best.has_area():
		return Rect2()
	var corner : Vector2 = waterline.offset - (Vector2(width, image.get_height()) / 2.0 if waterline.centered else Vector2.ZERO)
	var local : Rect2 = (global_transform.affine_inverse() * waterline.global_transform) * Rect2(corner + Vector2(best.position), best.size)
	return local.grow(-HOLE_MARGIN)

func _process(delta : float) -> void:
	var throttle : float = Input.get_axis("slow_down", "speed_up")
	if throttle != 0.0:
		if speedTween:
			speedTween.kill()
		speed = clampf(speed + throttle * testAcceleration * delta, 0.0, maxSpeed)
		targetSpeed = speed
	var motion : float = get_motion()
	if motion == appliedMotion:
		return
	appliedMotion = motion
	for effect in motionEffects:
		if effect.material is ShaderMaterial:
			effect.material.set_shader_parameter("motion", motion)
		else:
			effect.modulate.a = motion
	for item in movingOnly:
		item.visible = motion > 0.0

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("anchor"):
		if is_zero_approx(targetSpeed):
			change_speed(resumeSpeed if resumeSpeed > 0.0 else cruiseSpeed, startTime)
		else:
			resumeSpeed = targetSpeed
			stop()

func change_speed(target : float, duration : float = -1.0) -> Tween:
	targetSpeed = clampf(target, 0.0, maxSpeed)
	if duration < 0.0:
		duration = speedChangeTime * absf(targetSpeed - speed) / maxf(cruiseSpeed, 0.01)
	if speedTween:
		speedTween.kill()
	speedTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speedTween.tween_property(self, "speed", targetSpeed, duration)
	return speedTween

func stop(duration : float = -1.0) -> Tween:
	return change_speed(0.0, stopTime if duration < 0.0 else duration)

func get_motion() -> float:
	return clampf(speed / cruiseSpeed, 0.0, 1.0) if cruiseSpeed > 0.0 else 0.0

func is_stopped() -> bool:
	return is_zero_approx(speed)

func covers(point : Vector2) -> bool:
	for sprite in hull:
		if sprite.is_pixel_opaque(sprite.to_local(point)):
			return true
	return false

func overlaps_occluders(area : Rect2) -> bool:
	for sprite in occluders:
		if not usedRects.has(sprite.texture):
			usedRects[sprite.texture] = Rect2(sprite.texture.get_image().get_used_rect())
		var used : Rect2 = usedRects[sprite.texture]
		var corner : Vector2 = sprite.offset - (sprite.texture.get_size() / 2.0 if sprite.centered else Vector2.ZERO)
		if Rect2(sprite.to_global(used.position + corner), used.size).intersects(area):
			return true
	return false

func fade_occluders(value : bool) -> void:
	if value == faded:
		return
	faded = value
	if fadeTween:
		fadeTween.kill()
	fadeTween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for sprite in occluders:
		if not (sprite.get_parent() is Sprite2D and occluders.has(sprite.get_parent())):
			fadeTween.tween_property(sprite, "modulate:a", occluderFade if value else 1.0, occluderFadeTime)

func occluder_static() -> Dictionary:
	if occluderStatic.is_empty():
		var textures : Array[Texture2D] = []
		var modes : PackedInt32Array = PackedInt32Array()
		var first : PackedVector4Array = PackedVector4Array()
		var second : PackedVector4Array = PackedVector4Array()
		for i in 3:
			var occluder : Sprite2D = occluders[i] if i < occluders.size() else null
			var shaded : ShaderMaterial = occluder.material as ShaderMaterial if occluder else null
			textures.append(occluder.texture if occluder and occluder.texture else deck.texture)
			modes.append(0 if not occluder else (2 if shaded and shaded.get_shader_parameter("sail_rect") != null else 1))
			first.append(parameter(shaded, "sail_rect") if modes[i] == 2 else Vector4.ZERO)
			second.append(Vector4(parameter(shaded, "anchor_inset"), parameter(shaded, "strength"), parameter(shaded, "speed"), parameter(shaded, "ripple_frequency")) if modes[i] == 2 else Vector4.ZERO)
		occluderStatic = {"occluders": textures, "occluder_mode": modes, "occluder_a": first, "occluder_b": second}
	return occluderStatic

func apply_occluders(occluded : ShaderMaterial, enabled : bool) -> void:
	if not occluded.has_meta("occluders"):
		occluded.set_meta("occluders", true)
		var data : Dictionary = occluder_static()
		for key in data:
			occluded.set_shader_parameter(key, data[key])
	var frame : int = Engine.get_physics_frames()
	if frame != occluderFrame:
		occluderFrame = frame
		occluderAxes.resize(3)
		occluderOrigins.resize(3)
		for i in mini(occluders.size(), 3):
			var toTexel : Transform2D = texel_transform(occluders[i])
			occluderAxes[i] = Vector4(toTexel.x.x, toTexel.x.y, toTexel.y.x, toTexel.y.y)
			occluderOrigins[i] = toTexel.origin
	var rid : RID = occluded.get_rid()
	RenderingServer.material_set_param(rid, "occlude", enabled)
	RenderingServer.material_set_param(rid, "occluder_axes", occluderAxes)
	RenderingServer.material_set_param(rid, "occluder_origin", occluderOrigins)

static func texel_transform(sprite : Sprite2D) -> Transform2D:
	var region : Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	var corner : Vector2 = sprite.offset - (region.size / 2.0 if sprite.centered else Vector2.ZERO) - region.position
	return (sprite.global_transform * Transform2D(0.0, corner)).affine_inverse()

func parameter(shaded : ShaderMaterial, parameterName : StringName) -> Variant:
	var value : Variant = shaded.get_shader_parameter(parameterName)
	return value if value != null else RenderingServer.shader_get_parameter_default(shaded.shader.get_rid(), parameterName)

func is_solid(waterPoint : Vector2) -> bool:
	return deck != null and deck.is_pixel_opaque(deck.to_local(waterPoint - Vector2(0.0, deckHeight)))

func upgrade(upgradeScene : PackedScene) -> BoatUpgrade:
	var newUpgrade : BoatUpgrade = upgradeScene.instantiate()
	newUpgrade.boat = self
	visuals.add_child(newUpgrade)
	upgrades.append(newUpgrade)
	newUpgrade.apply()
	return newUpgrade

func remove_upgrade(oldUpgrade : BoatUpgrade) -> void:
	upgrades.erase(oldUpgrade)
	oldUpgrade.remove()
	oldUpgrade.queue_free()
