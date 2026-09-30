@tool
extends Node2D
class_name Ocean

const GROUP : StringName = &"oceans"
const SHADER_PARAMETERS : Array[String] = [
	"shallow_color", "deep_color", "caustic_color",
	"depth_scale", "depth_contrast", "depth_speed",
	"wave_scale", "wave_strength", "wave_speed",
	"clarity", "refraction_strength",
	"caustic_amount", "caustic_cell_size", "caustic_speed",
	"caustic_sharpness", "caustic_coverage", "caustic_patch_size",
]

#------------------------#
@export var sprite : Sprite2D
@export var ground : OceanGround
# The fish living here, also the ocean's journal page.
@export var biome : Biome

@export_group("Colors")
@export var shallow_color : Color = Color(0.18, 0.62, 0.78):
	set(value):
		shallow_color = value
		update_shader("shallow_color", value)
@export var deep_color : Color = Color(0.04, 0.17, 0.36):
	set(value):
		deep_color = value
		update_shader("deep_color", value)
@export var caustic_color : Color = Color(0.8, 1.0, 1.0):
	set(value):
		caustic_color = value
		update_shader("caustic_color", value)

@export_group("Depth")
@export var depth_scale : float = 64.0:
	set(value):
		depth_scale = value
		update_shader("depth_scale", value)
@export_range(0.0, 4.0) var depth_contrast : float = 1.6:
	set(value):
		depth_contrast = value
		update_shader("depth_contrast", value)
@export var depth_speed : float = 0.01:
	set(value):
		depth_speed = value
		update_shader("depth_speed", value)

@export_group("Waves")
@export var wave_scale : float = 20.0:
	set(value):
		wave_scale = value
		update_shader("wave_scale", value)
@export var wave_strength : float = 0.8:
	set(value):
		wave_strength = value
		update_shader("wave_strength", value)
@export var wave_speed : float = 0.8:
	set(value):
		wave_speed = value
		update_shader("wave_speed", value)

@export_group("Underwater")
@export_range(0.0, 1.0) var clarity : float = 0.55:
	set(value):
		clarity = value
		update_shader("clarity", value)
@export var refraction_strength : float = 2.5:
	set(value):
		refraction_strength = value
		update_shader("refraction_strength", value)

@export_group("Caustics")
@export_range(0.0, 8.0) var caustic_amount : float = 2.5:
	set(value):
		caustic_amount = value
		update_shader("caustic_amount", value)
@export_range(1.0, 64.0, 0.5) var caustic_cell_size : float = 9.0:
	set(value):
		caustic_cell_size = value
		update_shader("caustic_cell_size", value)
@export var caustic_speed : float = 0.7:
	set(value):
		caustic_speed = value
		update_shader("caustic_speed", value)
@export_range(1.0, 8.0) var caustic_sharpness : float = 3.5:
	set(value):
		caustic_sharpness = value
		update_shader("caustic_sharpness", value)
@export_range(0.0, 100.0, 1.0) var caustic_coverage : float = 100.0:
	set(value):
		caustic_coverage = value
		update_shader("caustic_coverage", value)
@export_range(4.0, 256.0, 1.0) var caustic_patch_size : float = 48.0:
	set(value):
		caustic_patch_size = value
		update_shader("caustic_patch_size", value)

@export_group("Flow")
@export var boat : Boat
@export var fallbackSpeed : float = 10.0
@export var decorationLayers : Array[DecorationLayer] = []
# The moment still water (see make_still) is frozen at.
@export var stillTime : float = 2.0

var scroll : Vector2 = Vector2.ZERO
var fieldsMaterial : ShaderMaterial = ShaderMaterial.new()
var cellsAMaterial : ShaderMaterial = ShaderMaterial.new()
var cellsBMaterial : ShaderMaterial = ShaderMaterial.new()
var fieldsViewport : SubViewport
var cellsAViewport : SubViewport
var cellsBViewport : SubViewport
var waterTexture : Texture2D
var bands : CanvasClip
var bandRects : Array[Rect2] = []
# Per shader, the uniforms it declares. Shared, as reading them is slow.
static var uniformNames : Dictionary = {}
# The passes still water shares, and the water using them now.
static var sharedPasses : Array[SubViewport] = []
static var sharedOwner : Ocean
var fieldsLayout : Array = []
var still : bool = false
# Frames the passes of still water keep rendering after it's shown, so they
# are ready whichever order the viewports are drawn in.
var stillFrames : int = 0
#------------------------#


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	fieldsMaterial.shader = preload("res://shaders/water_fields.gdshader")
	cellsAMaterial.shader = preload("res://shaders/caustic_cells.gdshader")
	cellsBMaterial.shader = cellsAMaterial.shader
	cellsBMaterial.set_shader_parameter("speed_scale", 1.3)
	if Engine.is_editor_hint():
		create_passes()
	for parameter in SHADER_PARAMETERS:
		update_shader(parameter, get(parameter))
	if sprite and sprite.texture and not Engine.is_editor_hint():
		waterTexture = sprite.texture
		sprite.texture = null
		bands = CanvasClip.new(sprite)

# Islands have water in several rooms and only show one at a time. Hidden
# water stops updating and rendering its passes.
func _notification(what : int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not Engine.is_editor_hint() and is_node_ready():
		refresh_passes()

# The passes are made the first time the water is shown or updated. Still
# water borrows one shared set instead, as only one island room shows at a
# time, so rooms and islands don't each make their own.
func create_passes() -> void:
	if fieldsViewport:
		return
	if still and not Engine.is_editor_hint():
		borrow_shared_passes()
	else:
		fieldsViewport = create_pass(fieldsMaterial)
		cellsAViewport = create_pass(cellsAMaterial)
		cellsBViewport = create_pass(cellsBMaterial)
	fieldsLayout = []

func borrow_shared_passes() -> void:
	if sharedPasses.is_empty():
		var holder : Node = Node.new()
		holder.name = "SharedWaterPasses"
		get_tree().root.add_child(holder)
		for i in 3:
			sharedPasses.append(create_pass(null, holder))
	if is_instance_valid(sharedOwner) and sharedOwner != self:
		sharedOwner.release_shared_passes()
	sharedOwner = self
	fieldsViewport = sharedPasses[0]
	cellsAViewport = sharedPasses[1]
	cellsBViewport = sharedPasses[2]
	for pair in [[fieldsViewport, fieldsMaterial], [cellsAViewport, cellsAMaterial], [cellsBViewport, cellsBMaterial]]:
		(pair[0].get_child(0) as ColorRect).material = pair[1]

# Another room's water took the shared passes; this one borrows them back
# when it's shown again.
func release_shared_passes() -> void:
	fieldsViewport = null
	cellsAViewport = null
	cellsBViewport = null
	fieldsLayout = []

func refresh_passes() -> void:
	var shown : bool = is_visible_in_tree()
	stillFrames = 3 if still and shown else 0
	set_process(shown)
	if shown and still:
		create_passes()
		update_fields()
	for viewport in [fieldsViewport, cellsAViewport, cellsBViewport]:
		if viewport:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED

# Holds the water still, for places the boat doesn't sail through (island
# rooms): no scrolling, the waves and caustics frozen at stillTime and the
# passes rendered just after it's shown (the island calls refresh_passes).
# The water and the seabed are only drawn where cover (the room's land)
# leaves them showing.
func make_still(cover : Sprite2D) -> void:
	still = true
	for target in [sprite.material if sprite else null, fieldsMaterial, cellsAMaterial, cellsBMaterial]:
		if target is ShaderMaterial:
			target.set_shader_parameter("still", true)
			target.set_shader_parameter("still_time", stillTime)
	if sprite and waterTexture:
		var rects : Array[Rect2] = CanvasClip.uncovered_rects(sprite, water_rect(), cover)
		bands = CanvasClip.new(sprite, rects.size())
		bandRects = rects
		bands.record(rects, draw_band)
	if ground:
		ground.draw_only(CanvasClip.uncovered_rects(ground, Rect2(Vector2.ZERO, ground.size), cover))

static func current_biome(tree : SceneTree) -> Biome:
	var ocean : Ocean = tree.get_first_node_in_group(GROUP) as Ocean
	return ocean.biome if ocean else null

func _process(delta : float) -> void:
	if still:
		# Nothing moves: the passes render a few frames after being shown, then stop.
		stillFrames -= 1
		if stillFrames <= 0:
			for viewport in [fieldsViewport, cellsAViewport, cellsBViewport]:
				if viewport:
					viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			set_process(false)
		return
	var distance : float = (boat.speed if boat and not Engine.is_editor_hint() else fallbackSpeed) * delta
	if ground:
		ground.scroll(distance)
	scroll.x += distance
	if not Engine.is_editor_hint():
		for layer in decorationLayers:
			layer.scroll(distance)
	update_fields()
	update_bands()

func water_texture() -> Texture2D:
	return waterTexture if waterTexture else (sprite.texture if sprite else null)

func update_bands() -> void:
	if not bands:
		return
	var hole : Rect2 = CanvasClip.inner_rect(sprite.global_transform.affine_inverse() * boat.global_transform, boat.opaque_rect()) if boat and CanvasClip.pixel_aligned(sprite) else Rect2()
	var rects : Array[Rect2] = CanvasClip.band_rects(water_rect(), hole)
	if rects == bandRects:
		return
	bandRects = rects
	bands.record(rects, draw_band)

func water_rect() -> Rect2:
	var size : Vector2 = waterTexture.get_size()
	return Rect2(sprite.offset - (size / 2.0 if sprite.centered else Vector2.ZERO), size)

func draw_band(item : RID) -> void:
	RenderingServer.canvas_item_add_texture_rect_region(item, water_rect(), waterTexture.get_rid(), Rect2(Vector2.ZERO, waterTexture.get_size()), Color(1, 1, 1), false, false)

func update_fields() -> void:
	if not sprite or not water_texture():
		return
	create_passes()
	var margin : int = ceili(absf(wave_strength)) + 2
	var texels : Vector2i = Vector2i(water_texture().get_size()) + Vector2i(margin, margin) * 2 + Vector2i.ONE
	var origin : Vector2 = (sprite.global_position + scroll).floor() - Vector2(margin, margin)
	var rid : RID = sprite.material.get_rid()
	RenderingServer.material_set_param(rid, "scroll", scroll)
	var layout : Array = [origin, texels, caustic_cell_size, sprite.material]
	if layout == fieldsLayout and not Engine.is_editor_hint():
		return
	fieldsLayout = layout
	resize_pass(fieldsViewport, texels)
	RenderingServer.material_set_param(fieldsMaterial.get_rid(), "fields_origin", origin)
	RenderingServer.material_set_param(rid, "fields", fieldsViewport.get_texture().get_rid())
	RenderingServer.material_set_param(rid, "fields_origin", origin)
	RenderingServer.material_set_param(rid, "fields_size", Vector2(texels))
	var cellSize : float = maxf(caustic_cell_size, 0.01)
	var area : Rect2 = Rect2(origin, texels)
	update_cells(cellsAViewport, cellsAMaterial, "a", area.position / cellSize, area.size / cellSize)
	update_cells(cellsBViewport, cellsBMaterial, "b", area.position / cellSize * 0.8 + Vector2(13.7, 7.3), area.size / cellSize * 0.8)

func update_cells(viewport : SubViewport, cellsMaterial : ShaderMaterial, layer : String, low : Vector2, span : Vector2) -> void:
	var start : Vector2 = low.floor() - Vector2.ONE
	resize_pass(viewport, Vector2i(span.ceil()) + Vector2i(4, 4))
	RenderingServer.material_set_param(cellsMaterial.get_rid(), "cells_origin", start)
	var rid : RID = sprite.material.get_rid()
	RenderingServer.material_set_param(rid, "cells_" + layer, viewport.get_texture().get_rid())
	RenderingServer.material_set_param(rid, "cells_%s_origin" % layer, start)

func create_pass(passMaterial : ShaderMaterial, parent : Node = null) -> SubViewport:
	var viewport : SubViewport = SubViewport.new()
	var canvas : ColorRect = ColorRect.new()
	canvas.material = passMaterial
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(canvas)
	if parent:
		parent.add_child(viewport)
	else:
		add_child(viewport, false, Node.INTERNAL_MODE_FRONT)
	return viewport

func resize_pass(viewport : SubViewport, texels : Vector2i) -> void:
	if viewport.size != texels:
		viewport.size = texels
		(viewport.get_child(0) as ColorRect).size = texels

func update_shader(parameter: String, value: Variant):
	for target in [sprite.material if sprite else null, fieldsMaterial, cellsAMaterial, cellsBMaterial]:
		if target is ShaderMaterial and declares(target, parameter):
			target.set_shader_parameter(parameter, value)

func declares(target : ShaderMaterial, parameter : String) -> bool:
	if not target.shader:
		return true
	if Engine.is_editor_hint() or not uniformNames.has(target.shader):
		var names : Dictionary = {}
		for uniform in target.shader.get_shader_uniform_list():
			names[uniform["name"]] = true
		uniformNames[target.shader] = names
	return uniformNames[target.shader].has(parameter)
