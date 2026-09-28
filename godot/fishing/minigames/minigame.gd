extends Node2D
class_name Minigame

signal finished(caught : bool)
# The fish pulled on the line, for splashing the bobber.
@warning_ignore("unused_signal")
signal tugged(strength : float)

# Every tuning range below is x = easiest, y = hardest. Ranges named by
# difficulty follow the fish's rarity, ranges named by heft follow how heavy the
# fish is for its kind. Each game also clamps its numbers so it stays winnable.

# Games are played on the MinigameScreen, which scales them up to fit and
# hands them clicks through use().

#------------------------#
# The play area, centered on the node.
@export var size : Vector2 = Vector2(48.0, 12.0)
# Shown under the game on the minigame screen.
@export var hint : String = ""
# How big the caught fish is drawn, in game pixels.
@export var fishSize : float = 8.0
@export var popTime : float = 0.3
@export var outTime : float = 0.18

@export_group("Look")
@export var frameColor : Color = Color(0.04, 0.07, 0.13, 1.0)
@export var backColor : Color = Color(0.1, 0.16, 0.25, 0.92)
@export var trackColor : Color = Color(0.2, 0.3, 0.42, 1.0)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var badColor : Color = Color(0.95, 0.38, 0.34)
@export var lightColor : Color = Color(0.94, 0.97, 1.0)

var difficulty : float = 0.0
var heft : float = 0.0
var accent : Color = Color.WHITE
var fishIcon : Texture2D
var holding : bool = false
# Set when the player gave up rather than lost.
var gaveUp : bool = false
var done : bool = false
var time : float = 0.0
var random : RandomNumberGenerator = RandomNumberGenerator.new()
#------------------------#


func begin(fishDifficulty : float, fishHeft : float, color : Color, icon : Texture2D = null) -> void:
	difficulty = clampf(fishDifficulty, 0.0, 1.0)
	heft = clampf(fishHeft, 0.0, 1.0)
	accent = color
	fishIcon = icon
	random.randomize()
	setup()
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, popTime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup() -> void:
	pass

@warning_ignore("unused_parameter")
func tick(delta : float) -> void:
	pass

func press() -> void:
	pass

func use() -> void:
	if not done:
		holding = true
		press()

func _physics_process(delta : float) -> void:
	holding = holding and Input.is_action_pressed("use")
	if not done:
		time += delta
		tick(delta)
	queue_redraw()

func finish(caught : bool) -> void:
	if done:
		return
	done = true
	holding = false
	finished.emit(caught)
	var tween : Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, outTime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func tune(span : Vector2) -> float:
	return lerpf(span.x, span.y, difficulty)

func weigh(span : Vector2) -> float:
	return lerpf(span.x, span.y, heft)

# A panel with a one pixel frame, and the inner area it leaves.
func draw_panel(area : Rect2, frame : Color) -> Rect2:
	draw_rect(area, frame)
	draw_rect(area.grow(-1.0), backColor)
	return area.grow(-2.0)

# The fish being caught, facing left or right, or a small marker in the
# rarity color when there's no icon.
func draw_fish(at : Vector2, facing : float, tilt : float = 0.0) -> void:
	if not fishIcon:
		draw_colored_polygon(PackedVector2Array([at + Vector2(-2.0, 0.0), at + Vector2(0.0, -1.5), at + Vector2(2.0, 0.0), at + Vector2(0.0, 1.5)]), accent)
		return
	var fit : float = fishSize / maxf(fishIcon.get_width(), fishIcon.get_height())
	draw_set_transform(at, tilt, Vector2(fit * (-1.0 if facing < 0.0 else 1.0), fit))
	draw_texture(fishIcon, -fishIcon.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO)

func draw_meter(area : Rect2, amount : float, vertical : bool, color : Color) -> void:
	draw_rect(area, trackColor)
	var fill : float = clampf(amount, 0.0, 1.0)
	if vertical:
		draw_rect(Rect2(area.position.x, area.end.y - area.size.y * fill, area.size.x, area.size.y * fill), color)
	else:
		draw_rect(Rect2(area.position, Vector2(area.size.x * fill, area.size.y)), color)
