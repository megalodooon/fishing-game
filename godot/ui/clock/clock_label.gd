extends Label
class_name ClockLabel


#------------------------#
@export var cycle : DayNightCycle
# Turns the time orange once it's past the full rest cutoff, pulsing redder
# toward passing out.
@export var sleep : SleepSchedule
@export var lateColor : Color = Color(1.0, 0.72, 0.4)
@export var urgentColor : Color = Color(1.0, 0.4, 0.36)

var time : float = 0.0
#------------------------#


func _ready() -> void:
	if cycle:
		cycle.time_changed.connect(show_time)

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
