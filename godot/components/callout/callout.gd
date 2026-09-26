extends Node2D
class_name Callout


#------------------------#
@export var font : Font
@export var fontSize : int = 8
@export var outlineColor : Color = Color(0.04, 0.07, 0.13, 1.0)
@export var outlineWidth : float = 1.0
@export var offset : Vector2 = Vector2.ZERO
@export var popTime : float = 0.35
@export var outTime : float = 0.18
@export var rise : float = 3.0
@export var bob : float = 0.0
@export var bobSpeed : float = 9.0

var boat : Boat
var anchor : Vector2 = Vector2.ZERO
var lift : float = 0.0
var time : float = 0.0
var text : String = ""
var color : Color = Color.WHITE
var textSize : Vector2 = Vector2.ZERO
var tween : Tween
#------------------------#


func _ready() -> void:
	set_process(false)

func _process(delta : float) -> void:
	time += delta
	if boat:
		anchor.x -= boat.speed * delta
	var screen : Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var point : Vector2 = anchor + offset - Vector2(0.0, lift + sin(time * bobSpeed) * bob)
	var half : float = textSize.x * 0.5 + outlineWidth
	position = Vector2(clampf(point.x, screen.position.x + half, screen.end.x - half), clampf(point.y, screen.position.y + textSize.y + outlineWidth, screen.end.y - outlineWidth))

func pop(at : Vector2, message : String, tint : Color, duration : float = 0.0) -> void:
	text = message
	color = tint
	textSize = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize)
	queue_redraw()
	anchor = at
	lift = 0.0
	time = 0.0
	scale = Vector2.ZERO
	show()
	set_process(true)
	_process(0.0)
	if tween:
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, popTime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "lift", rise, popTime + maxf(duration, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if duration > 0.0:
		tween.chain().tween_callback(dismiss)

func dismiss() -> void:
	if not visible:
		return
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, outTime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(finish)

func finish() -> void:
	hide()
	set_process(false)

func warm_up(characters : String) -> void:
	text = characters
	scale = Vector2.ZERO
	show()
	queue_redraw()
	await get_tree().process_frame
	if text == characters:
		finish()

func _draw() -> void:
	if not font or text.is_empty():
		return
	var origin : Vector2 = Vector2(-roundf(textSize.x * 0.5), -font.get_descent(fontSize))
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:
				draw_string(font, origin + Vector2(x, y) * outlineWidth, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, outlineColor)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)
