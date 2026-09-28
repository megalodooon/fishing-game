extends MenuPanel
class_name MinigameScreen

# The screen catch minigames are played on. It covers the game, scales the
# minigame up to fit and passes it the player's clicks. Right-click gives up.

#------------------------#
@export var font : Font
@export var backColor : Color = Color(0.03, 0.06, 0.11, 1.0)
@export var hintColor : Color = Color(0.58, 0.67, 0.78, 1.0)
@export var hintSize : int = 4
@export var giveUpText : String = "Right-click to give up"
@export var margin : float = 10.0
@export var maxScale : float = 3.0
@export var scaleStep : float = 0.5

var stage : Node2D
var game : Minigame
# Shown above the game, like which of several fish this is.
var caption : String = ""
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	stage = Node2D.new()
	add_child(stage)
	get_viewport().size_changed.connect(fit)
	fit()

func fit() -> void:
	place(Rect2(Vector2.ZERO, get_viewport_rect().size))
	arrange()

func play(minigame : Minigame) -> void:
	game = minigame
	game.tree_exited.connect(forget.bind(game))
	stage.add_child(game)
	arrange()
	open_menu()

func forget(minigame : Minigame) -> void:
	if game == minigame:
		game = null

func arrange() -> void:
	queue_redraw()
	if not game:
		return
	var text : float = hintSize * 2.0 + 6.0
	var room : Vector2 = size - Vector2(margin * 2.0, margin * 2.0 + text)
	var fitted : float = minf(room.x / game.size.x, room.y / game.size.y)
	var amount : float = clampf(floorf(fitted / scaleStep) * scaleStep, scaleStep, maxScale)
	stage.scale = Vector2.ONE * amount
	stage.position = Vector2(size.x * 0.5, (size.y - text) * 0.5).round()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and game:
		if event.button_index == MOUSE_BUTTON_LEFT:
			game.use()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			game.gaveUp = true
			game.finish(false)
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), backColor)
	if not font or not game:
		return
	if not caption.is_empty():
		draw_string(font, Vector2(0.0, stage.position.y - game.size.y * stage.scale.y * 0.5 - 5.0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, hintSize, hintColor)
	var y : float = stage.position.y + game.size.y * stage.scale.y * 0.5 + 6.0 + font.get_ascent(hintSize)
	draw_string(font, Vector2(0.0, y), game.hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, hintSize, hintColor)
	draw_string(font, Vector2(0.0, y + hintSize + 2.0), giveUpText, HORIZONTAL_ALIGNMENT_CENTER, size.x, hintSize - 1, Color(hintColor, 0.6))
