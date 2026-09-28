extends Control
class_name PeriodIcon

# Shows which part of the day it is next to the clock, and pops when the
# part changes. Each icon is shown from its start hour until the next one.

#------------------------#
@export var cycle : DayNightCycle
@export var icons : Array[Texture2D] = []
@export var starts : PackedFloat32Array = PackedFloat32Array()
@export var popTime : float = 0.45

var current : int = -1
var pop : float = 1.0
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if cycle:
		cycle.time_changed.connect(update_period.unbind(2))
		update_period()
	pop = 1.0

func period_at(time : float) -> int:
	var best : int = -1
	var latest : float = -1.0
	for i in mini(icons.size(), starts.size()):
		if starts[i] <= time and starts[i] > latest:
			best = i
			latest = starts[i]
	if best < 0:
		for i in mini(icons.size(), starts.size()):
			if starts[i] > latest:
				best = i
				latest = starts[i]
	return best

func update_period() -> void:
	var period : int = period_at(cycle.time)
	if period == current:
		return
	current = period
	pop = 0.0
	set_process(true)
	queue_redraw()

func _process(delta : float) -> void:
	pop = minf(pop + delta / popTime, 1.0)
	set_process(pop < 1.0)
	queue_redraw()

func _draw() -> void:
	if current < 0 or not icons[current]:
		return
	var icon : Texture2D = icons[current]
	var t : float = pop - 1.0
	var grow : float = 1.0 + t * t * (2.7 * t + 1.7) if pop < 1.0 else 1.0
	var shown : Vector2 = icon.get_size() * maxf(grow, 0.0)
	draw_texture_rect(icon, Rect2(((size - icon.get_size()) * 0.5).round() + (icon.get_size() - shown) * 0.5, shown), false)
