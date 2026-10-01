extends Node
class_name LoadingScreen

# Covers the switch into the game: loads the game scene and waits for the
# Preloader to have all the content in memory, so the game never stops to
# read from the disk later. Then it stays up a few frames while the game
# warms up behind it: shaders first used later on (the sea chart, sleeping,
# the rod's line and bobber) are drawn once so they get compiled now, and
# every letter the menus use is drawn at every text size so the font has
# them ready.

#------------------------#
@export_file("*.tscn") var gameScene : String = "res://test/test_scene.tscn"
@export var warmUpFrames : int = 8
# Materials to draw once behind the loading screen.
@export var warmMaterials : Array[Material] = []
# Shaders to draw once, and scenes whose materials to draw once.
@export var warmShaders : Array[Shader] = []
@export var warmScenes : Array[PackedScene] = []
# The menus' text sizes, and the letters to have ready in them.
@export var warmSizes : PackedInt32Array = PackedInt32Array([3, 4, 5, 6, 8])
@export var warmText : String = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

@onready var bar : ProgressBar = %Bar

var game : Node
var warmed : int = 0
var warmLayer : CanvasLayer
#------------------------#


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	ResourceLoader.load_threaded_request(gameScene)
	Preloader.start()

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Preloader.stop()

func _process(_delta : float) -> void:
	if game:
		warmed += 1
		bar.value = 100.0
		if warmed >= warmUpFrames:
			if warmLayer:
				warmLayer.queue_free()
			queue_free()
		return
	var progress : Array = []
	var status : ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(gameScene, progress)
	var content : float = Preloader.poll()
	bar.value = ((progress[0] if not progress.is_empty() else 0.0) * 0.3 + content * 0.6) * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED and Preloader.done():
		game = (ResourceLoader.load_threaded_get(gameScene) as PackedScene).instantiate()
		get_tree().root.add_child(game)
		get_tree().current_scene = game
		warm_up()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Failed to load " + gameScene)
		set_process(false)

# Draws the warm-up things on a layer just under this screen's, and builds the
# lookups the menus use, so none of them stalls the first time it opens.
func warm_up() -> void:
	GameEvent.all()
	RareDrops.all()
	Reforge.all()
	ShopStock.all()
	SkillRewards.build()
	Sources.build()
	Recipes.used_in(null)
	Collections.index_things(Catalog.things())
	Bazaar.traded()
	TrophyFishing.all()
	Museum.pieces()
	for id in Hunts.FAMILIES:
		load(Hunts.FAMILIES[id][2])
		load(Hunts.FAMILIES[id][3])
	Dialogue.load_all()
	warmLayer = CanvasLayer.new()
	warmLayer.layer = 99
	get_tree().root.add_child(warmLayer)
	var materials : Array[Material] = warmMaterials.duplicate()
	for shader in warmShaders:
		var material : ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		materials.append(material)
	for scene in warmScenes:
		var sample : Node = scene.instantiate()
		for node in [sample] + sample.find_children("*", "CanvasItem", true, false):
			if node is CanvasItem and (node as CanvasItem).material and not materials.has((node as CanvasItem).material):
				materials.append((node as CanvasItem).material)
		sample.free()
	for i in materials.size():
		var rect : ColorRect = ColorRect.new()
		rect.position = Vector2(i * 4.0, 0.0)
		rect.size = Vector2(4.0, 4.0)
		rect.material = materials[i]
		warmLayer.add_child(rect)
	var menus : Array[Node] = game.find_children("*", "InventoryUI", true, false)
	var ui : InventoryUI = menus.front() as InventoryUI if not menus.is_empty() else null
	if ui and ui.font:
		var writer : Control = Control.new()
		writer.position = Vector2(0.0, 8.0)
		writer.draw.connect(func() -> void:
			for size in warmSizes:
				writer.draw_string(ui.font, Vector2.ZERO, warmText, HORIZONTAL_ALIGNMENT_LEFT, -1, size))
		warmLayer.add_child(writer)
