extends MenuPanel
class_name DialogueUI

# The talking box at the bottom of the screen: the speaker's portrait and name
# tag, the text typing itself out, and choices at the end. Click, F, Space or
# Enter to go on, Esc to skip ahead. The game pauses while it's open. Also
# shows the full screen chapter cards.

const GROUP : StringName = &"dialogue_uis"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var charsPerSecond : float = 55.0
@export var boxHeight : float = 32.0
@export var textSize : int = 4
@export var cardTime : float = 3.2
@export var dimColor : Color = Color(0.0, 0.02, 0.05, 0.3)
@export var nameColor : Color = Color(0.09, 0.14, 0.22, 1.0)
# Parchment by default: dark ink on paper.
@export var skin : MenuSkin

var queue : Array = []
var index : int = 0
var typed : float = 0.0
var options : PackedStringArray = PackedStringArray()
var picked : int = 0
var done : Callable = Callable()
var box : Rect2
var optionRects : Array[Rect2] = []
var mouse : Vector2 = Vector2(-100.0, -100.0)
var cardTitle : String = ""
var cardSub : String = ""
var cardAge : float = -1.0
var wrapped : PackedStringArray = PackedStringArray()
var time : float = 0.0
var pausedBefore : bool = false
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	process_mode = PROCESS_MODE_ALWAYS
	slide = Vector2(0.0, 6.0)
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/paper.tres") as MenuSkin
	ui.laid_out.connect(fit)
	fit()

static func find(tree : SceneTree) -> DialogueUI:
	return tree.get_first_node_in_group(GROUP) as DialogueUI

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	box = Rect2(4.0, size.y - boxHeight - 3.0, size.x - 8.0, boxHeight)
	rewrap()

func _has_point(_point : Vector2) -> bool:
	return shown

func busy() -> bool:
	return shown or cardAge >= 0.0

# Plays a scene from the dialogue file, then calls done with the choice
# picked (or -1 when there were none).
func play(id : String, callback : Callable = Callable()) -> void:
	var lines : Array = Dialogue.lines(id)
	if lines.is_empty():
		if callback.is_valid():
			callback.call(-1)
		return
	start(lines, Dialogue.choices(id), callback)

# A single line, with choices, like an NPC's greeting.
func say(speaker : String, text : String, choices : PackedStringArray, callback : Callable = Callable()) -> void:
	start([[speaker, text]], choices, callback)

func start(lines : Array, choices : PackedStringArray, callback : Callable) -> void:
	queue = lines
	index = 0
	typed = 0.0
	options = choices
	picked = 0
	done = callback
	var counter : CounterUI = CounterUI.find(get_tree())
	if counter and counter.shown:
		counter.close()
	if not shown:
		pausedBefore = get_tree().paused
		get_tree().paused = true
		if player:
			player.frozen = true
	rewrap()
	open_menu()

func rewrap() -> void:
	if queue.is_empty() or index >= queue.size() or not ui:
		wrapped = PackedStringArray()
		return
	var width : float = box.size.x - (34.0 if portrait_of(queue[index][0]) else 8.0)
	wrapped = ui.wrap_lines(queue[index][1], width, textSize)

func portrait_of(speaker : String) -> Texture2D:
	return null if speaker == "narrator" else Cast.portrait(speaker)

func line_length() -> int:
	return queue[index][1].length() if index < queue.size() else 0

func at_end() -> bool:
	return index >= queue.size() - 1 and typed >= line_length()

func advance() -> void:
	if typed < line_length():
		typed = line_length()
		return
	if index < queue.size() - 1:
		index += 1
		typed = 0.0
		rewrap()
		return
	if options.is_empty():
		finish(-1)

func finish(choice : int) -> void:
	close_menu()
	get_tree().paused = pausedBefore
	if player:
		player.frozen = false
	var callback : Callable = done
	done = Callable()
	queue = []
	if callback.is_valid():
		callback.call(choice)

func card(title : String, subtitle : String) -> void:
	cardTitle = title
	cardSub = subtitle
	cardAge = 0.0
	visible = true
	modulate.a = 1.0

func _input(event : InputEvent) -> void:
	if cardAge >= 0.0:
		if event is InputEventMouseButton or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			cardAge = maxf(cardAge, cardTime - 0.5)
			get_viewport().set_input_as_handled()
		return
	if not shown:
		return
	if event is InputEventMouseMotion:
		mouse = (make_input_local(event) as InputEventMouse).position
		for i in optionRects.size():
			if optionRects[i].has_point(mouse):
				picked = i
		return
	var pressed : bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if at_end() and not options.is_empty():
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right") or event.is_action_pressed("down") or event.is_action_pressed("right"):
			picked = posmod(picked + 1, options.size())
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left") or event.is_action_pressed("up") or event.is_action_pressed("left"):
			picked = posmod(picked - 1, options.size())
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local : Vector2 = (make_input_local(event) as InputEventMouse).position
			for i in optionRects.size():
				if optionRects[i].has_point(local):
					finish(i)
		elif pressed:
			finish(picked)
		elif event.is_action_pressed("ui_cancel"):
			finish(options.size() - 1)
	elif pressed:
		advance()
	elif event.is_action_pressed("ui_cancel"):
		index = queue.size() - 1
		typed = line_length()
		rewrap()
	get_viewport().set_input_as_handled()

func _process(delta : float) -> void:
	time += delta
	if cardAge >= 0.0:
		if cardAge == 0.0:
			pausedBefore = get_tree().paused
			get_tree().paused = true
		cardAge += delta
		if cardAge >= cardTime:
			cardAge = -1.0
			get_tree().paused = pausedBefore
			if not shown:
				visible = false
		queue_redraw()
		return
	if shown and index < queue.size():
		typed = minf(typed + charsPerSecond * delta, line_length())
		queue_redraw()

func _draw() -> void:
	var font : Font = ui.font
	if cardAge >= 0.0:
		var fade : float = clampf(minf(cardAge / 0.5, (cardTime - cardAge) / 0.5), 0.0, 1.0)
		draw_rect(Rect2(-position, size + Vector2(20.0, 20.0)), Color(0.01, 0.02, 0.05, fade))
		draw_string(font, Vector2(0.0, size.y * 0.42), cardSub, HORIZONTAL_ALIGNMENT_CENTER, size.x, textSize, Color(ui.dimColor, fade))
		draw_string(font, Vector2(0.0, size.y * 0.42 + 12.0), cardTitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(ui.selectedColor, fade))
		return
	if queue.is_empty() or index >= queue.size():
		return
	draw_rect(Rect2(-position, size + Vector2(20.0, 20.0)), dimColor)
	var speaker : String = queue[index][0]
	var face : Texture2D = portrait_of(speaker)
	draw_rect(Rect2(box.position + Vector2(2.0, 2.0), box.size), Color(0.0, 0.0, 0.0, 0.35))
	UiKit.box(self, skin.frame, box)
	var textX : float = box.position.x + 5.0
	if face:
		var frame : Rect2 = Rect2(box.position + Vector2(3.0, 3.0), Vector2(26.0, 26.0))
		UiKit.box(self, skin.card, frame)
		var zoom : float = floorf(24.0 / maxf(face.get_width(), face.get_height()) * 2.0) * 0.5
		draw_texture_rect(face, Rect2(frame.get_center() - face.get_size() * zoom * 0.5, face.get_size() * zoom), false)
		textX = frame.end.x + 4.0
	if speaker != "narrator":
		var label : String = Cast.name_of(speaker)
		var width : float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 8.0
		var tag : Rect2 = Rect2(textX - 1.0, box.position.y - 6.0, width, 8.0)
		var tint : Color = Cast.color_of(speaker)
		draw_rect(tag, Color(0.12, 0.08, 0.05))
		draw_rect(tag.grow(-1.0), tint.darkened(0.55))
		draw_rect(Rect2(tag.position.x + 1.0, tag.position.y + 1.0, tag.size.x - 2.0, 1.0), tint.darkened(0.3))
		draw_string(font, Vector2(tag.position.x + 4.0, tag.position.y + 2.0 + font.get_ascent(ui.statSize)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, tint.lightened(0.35))
	var left : int = int(typed)
	var y : float = box.position.y + 4.0
	var color : Color = skin.text if speaker != "narrator" else skin.dim
	for line in wrapped:
		if left <= 0:
			break
		var part : String = line.substr(0, left)
		left -= line.length() + 1
		draw_string(font, Vector2(textX, y + font.get_ascent(textSize)), part, HORIZONTAL_ALIGNMENT_LEFT, -1, textSize, color)
		y += textSize + 2.0
	optionRects.clear()
	if at_end() and not options.is_empty():
		var x : float = box.end.x - 3.0
		for i in range(options.size() - 1, -1, -1):
			var width : float = font.get_string_size(options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 8.0
			x -= width
			var area : Rect2 = Rect2(x, box.end.y - 10.0, width, 8.0)
			optionRects.push_front(area)
			var active : bool = i == picked
			UiKit.button(self, font, skin, area, options[i], ui.statSize, true, active)
			x -= 2.0
	elif typed >= line_length() and fmod(time, 0.8) < 0.5:
		var tip : Vector2 = Vector2(box.end.x - 6.0, box.end.y - 5.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-1.5, -1.0), tip + Vector2(1.5, -1.0), tip + Vector2(0.0, 0.8)]), skin.title)
