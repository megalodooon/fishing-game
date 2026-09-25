extends Node
class_name LoadingScreen


#------------------------#
@export_file("*.tscn") var gameScene : String = "res://test/test_scene.tscn"
@export var warmUpFrames : int = 8

@onready var bar : ProgressBar = %Bar

var game : Node
var warmed : int = 0
#------------------------#


func _ready() -> void:
	ResourceLoader.load_threaded_request(gameScene)

func _process(_delta : float) -> void:
	if game:
		warmed += 1
		bar.value = 100.0
		if warmed >= warmUpFrames:
			queue_free()
		return
	var progress : Array = []
	var status : ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(gameScene, progress)
	if not progress.is_empty():
		bar.value = progress[0] * 90.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		game = (ResourceLoader.load_threaded_get(gameScene) as PackedScene).instantiate()
		get_tree().root.add_child(game)
		get_tree().current_scene = game
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Failed to load " + gameScene)
		set_process(false)
