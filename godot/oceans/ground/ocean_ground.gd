@tool
extends Node2D
class_name OceanGround

const PARAMETERS : Array[String] = [
	"depth_scale", "depth_contrast", "depth_bias",
	"color_bands", "relief", "light_direction", "grain", "speckle_density", "speckle_strength", "fog_color", "fog_amount",
	"ripple_scale", "ripple_angle", "ripple_strength", "ripple_warp", "ripple_max_depth",
	"grass_cell", "grass_density", "grass_depth", "grass_softness", "grass_blades", "grass_height", "grass_spread",
]

#------------------------#
@export var size : Vector2 = Vector2(192, 108)
@export var groundSeed : int = 0
@export var randomSeed : bool = true
@export_tool_button("New Seed", "RandomNumberGenerator") var newSeedButton : Callable = new_seed

@export_group("Depth")
@export var depth_scale : float = 90.0
@export_range(0.0, 4.0) var depth_contrast : float = 1.4
@export_range(-1.0, 1.0) var depth_bias : float = 0.0

@export_group("Colors")
@export var ground_colors : Gradient
@export_range(0, 16) var color_bands : int = 6
@export_range(0.0, 3.0) var relief : float = 0.35
@export var light_direction : Vector2 = Vector2(-0.7, -0.7)
@export_range(0.0, 0.5) var grain : float = 0.04
@export_range(0.0, 0.2) var speckle_density : float = 0.03
@export_range(0.0, 1.0) var speckle_strength : float = 0.12
@export var fog_color : Color = Color(0.1, 0.2, 0.28)
@export_range(0.0, 1.0) var fog_amount : float = 0.3

@export_group("Ripples")
@export var ripple_scale : float = 5.0
@export_range(-3.1416, 3.1416) var ripple_angle : float = 0.4
@export_range(0.0, 0.5) var ripple_strength : float = 0.06
@export var ripple_warp : float = 1.5
@export_range(0.0, 1.0) var ripple_max_depth : float = 0.45

@export_group("Grass")
@export var grass_colors : Gradient
@export var grass_cell : float = 12.0
@export_range(0.0, 1.0) var grass_density : float = 0.25
@export var grass_depth : Vector2 = Vector2(0.2, 0.65)
@export_range(0.0, 0.5) var grass_softness : float = 0.08
@export var grass_blades : Vector2 = Vector2(3.0, 6.0)
@export var grass_height : Vector2 = Vector2(2.0, 4.0)
@export var grass_spread : float = 3.0

var offset : float = 0.0
var renderedScroll : float = NAN
var groundTexture : GradientTexture1D = GradientTexture1D.new()
var grassTexture : GradientTexture1D = GradientTexture1D.new()
var viewport : SubViewport
var canvas : ColorRect
var display : Sprite2D
#------------------------#


func _ready() -> void:
	if randomSeed and not Engine.is_editor_hint():
		groundSeed = randi() % 10000
	viewport = SubViewport.new()
	canvas = ColorRect.new()
	display = Sprite2D.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if Engine.is_editor_hint() else SubViewport.UPDATE_DISABLED
	viewport.add_child(canvas)
	display.centered = false
	display.texture = viewport.get_texture()
	add_child(viewport, false, Node.INTERNAL_MODE_FRONT)
	add_child(display, false, Node.INTERNAL_MODE_FRONT)

func _process(_delta : float) -> void:
	if not material or not viewport:
		return
	var texels : Vector2i = Vector2i(ceili(size.x) + 1, ceili(size.y))
	if viewport.size != texels:
		viewport.size = texels
		canvas.size = texels
		renderedScroll = NAN
	if canvas.material != material:
		canvas.material = material
		renderedScroll = NAN
	display.region_enabled = true
	display.region_rect = Rect2(offset - floorf(offset), 0.0, size.x, size.y)
	if floorf(offset) == renderedScroll and not Engine.is_editor_hint():
		return
	renderedScroll = floorf(offset)
	if not Engine.is_editor_hint():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rid : RID = material.get_rid()
	for parameter in PARAMETERS:
		RenderingServer.material_set_param(rid, parameter, get(parameter))
	groundTexture.gradient = ground_colors
	grassTexture.gradient = grass_colors
	RenderingServer.material_set_param(rid, "ground_colors", groundTexture.get_rid())
	RenderingServer.material_set_param(rid, "grass_colors", grassTexture.get_rid())
	RenderingServer.material_set_param(rid, "seed_offset", seed_offset())
	RenderingServer.material_set_param(rid, "scroll", floorf(offset))

func scroll(distance : float) -> void:
	offset += distance

func new_seed() -> void:
	groundSeed = randi() % 10000
	refresh()

func refresh() -> void:
	renderedScroll = NAN

func seed_offset() -> Vector2:
	return Vector2((groundSeed * 7919) % 10007, (groundSeed * 104729) % 10009)

func get_depth(point : Vector2) -> float:
	var q : Vector2 = point / depth_scale + seed_offset()
	var n : float = value_noise(q) * 0.6 + value_noise(q * 2.13 + Vector2(7.7, 7.7)) * 0.3 + value_noise(q * 4.7 + Vector2(3.1, 3.1)) * 0.1
	return clampf((n - 0.5) * depth_contrast + 0.5 + depth_bias, 0.0, 1.0)

static func value_noise(p : Vector2) -> float:
	var i : Vector2 = p.floor()
	var f : Vector2 = p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var x : int = int(i.x)
	var y : int = int(i.y)
	return lerpf(
		lerpf(noise_hash(x, y), noise_hash(x + 1, y), f.x),
		lerpf(noise_hash(x, y + 1), noise_hash(x + 1, y + 1), f.x),
		f.y)

static func noise_hash(ix : int, iy : int) -> float:
	var x : int = ix & 0xFFFFFFFF
	var y : int = iy & 0xFFFFFFFF
	var qx : int = (1103515245 * ((x >> 1) ^ y)) & 0xFFFFFFFF
	var qy : int = (1103515245 * ((y >> 1) ^ x)) & 0xFFFFFFFF
	var n : int = (1103515245 * (qx ^ (qy >> 3))) & 0xFFFFFFFF
	return n / 4294967295.0
