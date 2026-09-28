extends Control
class_name MenuPanel

# A menu that fades and slides into place instead of popping into existence,
# and back out when it closes. Subclasses draw their content as usual and call
# super() from _ready. place() sets where it rests.

signal opened
signal closed

#------------------------#
@export var openTime : float = 0.16
@export var closeTime : float = 0.1
# Where it starts from when opening, relative to where it rests.
@export var slide : Vector2 = Vector2(0.0, 4.0)
@export var blocksMouse : bool = true

var shown : bool = false
var home : Vector2 = Vector2.ZERO
var motion : Tween
#------------------------#


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE

func place(area : Rect2) -> void:
	home = area.position
	size = area.size
	if not motion or not motion.is_running():
		position = home if shown else home + slide

func open_menu() -> void:
	if shown:
		return
	shown = true
	if not visible:
		position = home + slide
		visible = true
	mouse_filter = MOUSE_FILTER_STOP if blocksMouse else MOUSE_FILTER_IGNORE
	animate(1.0, openTime, Tween.EASE_OUT)
	opened.emit()

func close_menu() -> void:
	if not shown:
		return
	shown = false
	mouse_filter = MOUSE_FILTER_IGNORE
	var focused : Control = get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused):
		focused.release_focus()
	animate(0.0, closeTime, Tween.EASE_IN)
	closed.emit()

func toggle_menu() -> void:
	if shown:
		close_menu()
	else:
		open_menu()

func animate(to : float, duration : float, easing : Tween.EaseType) -> void:
	if motion:
		motion.kill()
	motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	motion.tween_property(self, "modulate:a", to, duration)
	motion.tween_property(self, "position", home + slide * (1.0 - to), duration)
	if to <= 0.0:
		motion.chain().tween_callback(hide)
