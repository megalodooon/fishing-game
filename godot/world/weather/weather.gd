extends Node
class_name Weather

# The weather where the boat is. It can change at a few set hours a day, and
# the same place, day and hour always get the same weather, so tomorrow can
# be forecast. Rain makes fish bite faster, fog brings up rarer fish, and some
# fish only bite in one or the other. A place's Location can change the odds.

signal changed(state : int)

enum State { CLEAR, RAIN, FOG }
const NAMES : PackedStringArray = ["Clear", "Rain", "Fog"]
const GROUP : StringName = &"weathers"

#------------------------#
@export var cycle : DayNightCycle
@export var player : Player
@export var notices : NoticeBoard
# One per State, for the HUD and notices.
@export var icons : Array[Texture2D] = []
# How likely each state is (clear, rain, fog) where the Location doesn't say.
@export var chances : PackedFloat32Array = PackedFloat32Array([0.55, 0.27, 0.18])
# The hours the weather can change at, in order.
@export var changeHours : PackedFloat32Array = PackedFloat32Array([6.0, 15.0])
# Draws the rain and fog. Turned off in the settings to save the GPU.
@export var showEffects : bool = true:
	set(value):
		showEffects = value
		if overlay:
			overlay.visible = value

@export_group("Effects")
@export var rainBiteSpeed : float = 1.3
# How much likelier rare, legendary and trophy fish are.
@export var fogLuck : float = 1.6
@export var rainColor : Color = Color(0.55, 0.75, 1.0)
@export var fogColor : Color = Color(0.82, 0.86, 0.92)

var state : int = State.CLEAR
# Set by the developer menu. -1 lets the weather be.
var forced : int = -1
var overlay : WeatherOverlay
var ready_done : bool = false
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	overlay = WeatherOverlay.new()
	overlay.visible = showEffects
	layer.add_child(overlay)
	if cycle:
		cycle.time_changed.connect(refresh.unbind(2))
	if player and player.atlas:
		player.atlas.changed.connect(refresh)
	state = pick_now()
	overlay.set_state(state, true)
	ready_done = true

static func find(tree : SceneTree) -> Weather:
	return tree.get_first_node_in_group(GROUP) as Weather if tree else null

static func now_state(tree : SceneTree) -> int:
	var weather : Weather = find(tree)
	return weather.state if weather else State.CLEAR

func icon(which : int) -> Texture2D:
	return icons[which] if which >= 0 and which < icons.size() else null

func place_chances() -> PackedFloat32Array:
	var location : Location = player.atlas.current if player and player.atlas else null
	return location.weatherChances if location and location.weatherChances.size() == 3 else chances

# Which of the day's weather periods an hour falls in. Hours before the first
# change still belong to the day before's last period.
func period(day : int, hour : float) -> Vector2i:
	var index : int = -1
	for i in changeHours.size():
		if hour >= changeHours[i]:
			index = i
	if index < 0:
		return Vector2i(day - 1, changeHours.size() - 1)
	return Vector2i(day, index)

func state_at(day : int, hour : float, odds : PackedFloat32Array) -> int:
	var at : Vector2i = period(day, hour)
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([at.x, at.y, player.atlas.current.resource_path if player and player.atlas and player.atlas.current else ""])
	var total : float = 0.0
	for chance in odds:
		total += chance
	var left : float = random.randf() * total
	for i in odds.size():
		left -= odds[i]
		if left < 0.0:
			return i
	return State.CLEAR

func pick_now() -> int:
	if forced >= 0:
		return forced
	var ordered : Dictionary = player.progress.get_flag("weather_order", {}) if player and player.progress else {}
	if cycle and ordered.get("day", -1) == cycle.day:
		return ordered.state
	if not cycle:
		return State.CLEAR
	return state_at(cycle.day, cycle.time, place_chances())

# What the weather will be like tomorrow around noon here.
func forecast() -> int:
	return state_at(cycle.day + 1, 12.0, place_chances()) if cycle else State.CLEAR

func refresh() -> void:
	var next : int = pick_now()
	if next == state:
		return
	state = next
	overlay.set_state(state, false)
	changed.emit(state)
	if notices and ready_done:
		match state:
			State.RAIN:
				notices.post("It's raining", "Fish bite faster in the rain, and some only come out now.", rainColor, icon(state))
			State.FOG:
				notices.post("Fog rolls in", "Rare fish swim up under the fog.", fogColor, icon(state))
			_:
				notices.post("Skies clear up", "The weather is calm again.", Color(1.0, 0.9, 0.4), icon(state))

func force(which : int) -> void:
	forced = which
	refresh()

func stat(property : StringName) -> float:
	if property == &"biteSpeed" and state == State.RAIN:
		return rainBiteSpeed
	if property == &"luck":
		return luck()
	return 1.0

# How much likelier rare fish are right now.
func luck() -> float:
	return fogLuck if state == State.FOG else 1.0

func effect_text(which : int) -> String:
	match which:
		State.RAIN:
			return "Bites x%.1f" % rainBiteSpeed
		State.FOG:
			return "Rare fish x%.1f" % fogLuck
	return "No effect"
