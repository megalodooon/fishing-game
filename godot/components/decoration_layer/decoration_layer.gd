extends TileMapLayer
class_name DecorationLayer

const AREA : Vector2i = Vector2i(192, 108)

#------------------------#
@export var decorations : Array[Texture2D] = []
@export var cellSize : Vector2i = Vector2i(16, 16)
@export_range(0.0, 100.0, 1.0, "suffix:%") var amount : float = 30.0
@export var randomAmount : bool = false
@export_range(0.0, 100.0, 1.0, "suffix:%") var minAmount : float = 0.0
@export_range(0.0, 100.0, 1.0, "suffix:%") var maxAmount : float = 5.0
@export var ground : OceanGround
@export var depthRange : Vector2 = Vector2(0.0, 0.35)

var columns : int
var rows : int
var firstColumn : int = 0
#------------------------#


func _ready() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = cellSize
	for texture in decorations:
		var source : TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(texture.get_size())
		source.create_tile(Vector2i.ZERO)
		tile_set.add_source(source)
	columns = ceili(AREA.x / float(cellSize.x)) + 1
	rows = ceili(AREA.y / float(cellSize.y))
	for x in columns:
		spawn_column(x)

func scroll(distance : float) -> void:
	position.x -= distance
	while position.x + (firstColumn + 1) * cellSize.x < 0.0:
		for y in rows:
			erase_cell(Vector2i(firstColumn, y))
		spawn_column(firstColumn + columns)
		firstColumn += 1

func spawn_column(x : int) -> void:
	if decorations.is_empty():
		return
	var chance : float = (randf_range(minAmount, maxAmount) if randomAmount else amount) / 100.0
	for y in rows:
		if ground:
			var depth : float = ground.get_depth(Vector2(Vector2i(x, y) * cellSize) + cellSize / 2.0)
			if depth < depthRange.x or depth > depthRange.y:
				continue
		if randf() < chance:
			set_cell(Vector2i(x, y), randi() % decorations.size(), Vector2i.ZERO)
