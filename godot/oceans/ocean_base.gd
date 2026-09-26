@tool
extends Node2D
class_name Ocean

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

var scroll : Vector2 = Vector2.ZERO
var fieldsMaterial : ShaderMaterial = ShaderMaterial.new()
var cellsAMaterial : ShaderMaterial = ShaderMaterial.new()
var cellsBMaterial : ShaderMaterial = ShaderMaterial.new()
var fieldsViewport : SubViewport
var cellsAViewport : SubViewport
var cellsBViewport : SubViewport
var waterTexture : Texture2D
var bands : CanvasClip
var bandKey : Array = []
var uniformNames : Dictionary = {}
var fieldsLayout : Array = []
#------------------------#


func _ready() -> void:
	fieldsMaterial.shader = preload("res://shaders/water_fields.gdshader")
	cellsAMaterial.shader = preload("res://shaders/caustic_cells.gdshader")
	cellsBMaterial.shader = cellsAMaterial.shader
	cellsBMaterial.set_shader_parameter("speed_scale", 1.3)
	fieldsViewport = create_pass(fieldsMaterial)
	cellsAViewport = create_pass(cellsAMaterial)
	cellsBViewport = create_pass(cellsBMaterial)
	for parameter in SHADER_PARAMETERS:
		update_shader(parameter, get(parameter))
	if sprite and sprite.texture and not Engine.is_editor_hint():
		waterTexture = sprite.texture
		sprite.texture = null
		bands = CanvasClip.new(sprite)

func _process(delta : float) -> void:
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
	var key : Array = [sprite.get_global_transform_with_canvas(), sprite.get_viewport().get_final_transform(), boat.global_transform if boat else Transform2D()]
	if key == bandKey:
		return
	bandKey = key
	var hole : Rect2 = sprite.global_transform.affine_inverse() * (boat.global_transform * boat.opaque_rect()) if boat and CanvasClip.pixel_aligned(sprite) else Rect2()
	bands.record(CanvasClip.band_rects(water_rect(), hole), draw_band)

func water_rect() -> Rect2:
	var size : Vector2 = waterTexture.get_size()
	return Rect2(sprite.offset - (size / 2.0 if sprite.centered else Vector2.ZERO), size)

func draw_band(item : RID) -> void:
	RenderingServer.canvas_item_add_texture_rect_region(item, water_rect(), waterTexture.get_rid(), Rect2(Vector2.ZERO, waterTexture.get_size()), Color(1, 1, 1), false, false)

func update_fields() -> void:
	if not sprite or not water_texture() or not fieldsViewport:
		return
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
	update_cells(cellsAViewport, cellsAMaterial, "a", area.position / cellSize, area.end / cellSize)
	update_cells(cellsBViewport, cellsBMaterial, "b", area.position / cellSize * 0.8 + Vector2(13.7, 7.3), area.end / cellSize * 0.8 + Vector2(13.7, 7.3))

func update_cells(viewport : SubViewport, cellsMaterial : ShaderMaterial, layer : String, low : Vector2, high : Vector2) -> void:
	var start : Vector2 = low.floor() - Vector2.ONE
	resize_pass(viewport, Vector2i(high.floor() - start) + Vector2i(2, 2))
	RenderingServer.material_set_param(cellsMaterial.get_rid(), "cells_origin", start)
	var rid : RID = sprite.material.get_rid()
	RenderingServer.material_set_param(rid, "cells_" + layer, viewport.get_texture().get_rid())
	RenderingServer.material_set_param(rid, "cells_%s_origin" % layer, start)

func create_pass(passMaterial : ShaderMaterial) -> SubViewport:
	var viewport : SubViewport = SubViewport.new()
	var canvas : ColorRect = ColorRect.new()
	canvas.material = passMaterial
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(canvas)
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
