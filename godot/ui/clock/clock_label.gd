extends Label
class_name ClockLabel


#------------------------#
@export var cycle : DayNightCycle
# Turns the time orange once it's past the full rest cutoff, pulsing redder
# toward passing out.
@export var sleep : SleepSchedule
@export var lateColor : Color = Color(1.0, 0.72, 0.4)
@export var urgentColor : Color = Color(1.0, 0.4, 0.36)
# Shows the weekday and the day number, like "Sun 7".
@export var dayLabel : Label
# Scaled with the rest of the HUD (the UI size setting).
@export var ui : InventoryUI

var time : float = 0.0
var home : Vector2
var dayHome : Vector2
#------------------------#


func _ready() -> void:
	home = position
	dayHome = dayLabel.position if dayLabel else Vector2.ZERO
	if ui:
		ui.laid_out.connect(follow_ui)
		follow_ui()
	if cycle:
		cycle.time_changed.connect(show_time)
		cycle.day_changed.connect(show_day)
		show_day(cycle.day)

func follow_ui() -> void:
	scale = ui.scale
	position = home * ui.scale
	if dayLabel:
		dayLabel.scale = ui.scale
		dayLabel.position = dayHome * ui.scale

func _process(delta : float) -> void:
	time += delta
	var late : float = sleep.lateness() if sleep else 0.0
	var color : Color = Color.WHITE
	if late > 0.0:
		var pulse : float = 0.5 + 0.5 * sin(time * TAU * lerpf(0.6, 1.6, late))
		color = lateColor.lerp(urgentColor, late).lerp(Color.WHITE, pulse * 0.3)
	if self_modulate != color:
		self_modulate = color

func _unhandled_input(event : InputEvent) -> void:
	if cycle and event.is_action_pressed("ui_down"):
		cycle.set_time(cycle.time + 1.0)

func show_time(hour : int, minute : int) -> void:
	text = "%02d:%02d" % [hour, minute]

func show_day(day : int) -> void:
	if dayLabel:
		dayLabel.text = "%s %d" % [cycle.weekday_name(true), day]
