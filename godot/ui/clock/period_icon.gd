extends Control
class_name PeriodIcon

# Shows which part of the day it is next to the clock, and pops when the
# part changes. Each icon is shown from its start hour until the next one.

#------------------------#
@export var cycle : DayNightCycle
@export var icons : Array[Texture2D] = []
@export var starts : PackedFloat32Array = PackedFloat32Array()
@export var popTime : float = 0.45
# Scaled with the rest of the HUD (the UI size setting).
@export var ui : InventoryUI
# The plate behind the clock, the day and the weather, from this icon's corner.
@export var plate : Rect2 = Rect2(-1.0, -0.5, 59.0, 15.0)
@export var plateColor : Color = Color(0.03, 0.06, 0.11, 0.55)
@export var plateEdge : Color = Color(0.3, 0.42, 0.57, 0.5)

var current : int = -1
var home : Vector2
var pop : float = 1.0
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	home = position
	if ui:
		ui.laid_out.connect(func() -> void:
			scale = ui.scale
			position = home * ui.scale)
		scale = ui.scale
		position = home * ui.scale
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
	if plate.size.x > 0.0:
		draw_rect(plate, plateColor)
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1.0)), plateEdge)
		draw_rect(Rect2(plate.position.x, plate.end.y - 1.0, plate.size.x, 1.0), Color(0.0, 0.0, 0.0, 0.3))
	if current < 0 or not icons[current]:
		return
	var icon : Texture2D = icons[current]
	var t : float = pop - 1.0
	var grow : float = 1.0 + t * t * (2.7 * t + 1.7) if pop < 1.0 else 1.0
	var shown : Vector2 = icon.get_size() * maxf(grow, 0.0)
	draw_texture_rect(icon, Rect2(((size - icon.get_size()) * 0.5).round() + (icon.get_size() - shown) * 0.5, shown), false)
