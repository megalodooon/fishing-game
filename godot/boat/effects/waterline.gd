@tool
extends Sprite2D
class_name BoatWaterline

const MAX_COLUMNS : int = 128

@export var edgeTexture : Texture2D:
	set(value):
		edgeTexture = value
		if is_node_ready():
			bake()
@export_range(0, 8) var smoothing : int = 3:
	set(value):
		smoothing = value
		if is_node_ready():
			bake()

var flow : float = 0.0


func _ready() -> void:
	texture_changed.connect(bake)
	bake()

func _process(delta : float) -> void:
	var visuals : Node2D = get_parent() as Node2D
	if material and visuals:
		var motion : Variant = material.get_shader_parameter("motion")
		flow += delta * (motion if motion != null else 0.0)
		RenderingServer.material_set_param(material.get_rid(), "bob", Vector2(visuals.position.y, visuals.rotation))
		RenderingServer.material_set_param(material.get_rid(), "flow", flow)

func bake() -> void:
	if not texture or not material:
		return
	var image : Image = (edgeTexture if edgeTexture else texture).get_image()
	var edges : PackedFloat32Array = PackedFloat32Array()
	edges.resize(MAX_COLUMNS)
	for x in mini(image.get_width(), MAX_COLUMNS):
		for y in range(image.get_height() - 1, -1, -1):
			if image.get_pixel(x, y).a > 0.0:
				edges[x] = y + 1
				break
	var smoothed : PackedFloat32Array = edges.duplicate()
	for x in MAX_COLUMNS:
		if edges[x] <= 0.0:
			continue
		var total : float = 0.0
		var weight : float = 0.0
		for shift in range(-smoothing, smoothing + 1):
			var i : int = x + shift
			if i >= 0 and i < MAX_COLUMNS and edges[i] > 0.0:
				var w : float = smoothing + 1.0 - absi(shift)
				total += edges[i] * w
				weight += w
		smoothed[x] = maxf(total / weight, edges[x])
	material.set_shader_parameter("edges", smoothed)
