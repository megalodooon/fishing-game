extends Label
class_name ClockLabel


#------------------------#
@export var cycle : DayNightCycle
#------------------------#


func _ready() -> void:
	if cycle:
		cycle.time_changed.connect(show_time)

func _unhandled_input(event : InputEvent) -> void:
	if cycle and event.is_action_pressed("ui_down"):
		cycle.set_time(cycle.time + 1.0)

func show_time(hour : int, minute : int) -> void:
	text = "%02d:%02d" % [hour, minute]
