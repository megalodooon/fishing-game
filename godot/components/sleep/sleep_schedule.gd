extends CanvasLayer
class_name SleepSchedule

# Bedtime. Sleeping before fullRestHour refills all energy, sleeping later
# only lateRest of it, and at passOutHour the player collapses and wakes with
# passOutRest. Either way the next morning starts at wakeHour. Notices warn
# before each cutoff, the screen edges darken and the eyes start to droop as
# it gets late. The bed in the village house is the only place to sleep.

signal slept(share : float)
# The new day has begun behind closed eyes, before the summary shows.
signal slept_night

const GROUP : StringName = &"sleep_schedules"

#------------------------#
@export var cycle : DayNightCycle
@export var player : Player
@export var ui : InventoryUI
@export var notices : NoticeBoard
# Closed when falling asleep.
@export var menus : Array[Control] = []
@export var bedText : String = "Head to a bed: at home in the village, or a room you rent."

@export_group("Rules")
@export_range(0.0, 24.0, 0.25) var wakeHour : float = 7.0
# Going to sleep only works from this hour on.
@export_range(0.0, 24.0, 0.25) var earliestSleepHour : float = 20.0
@export_range(0.0, 24.0, 0.25) var fullRestHour : float = 2.0
@export_range(0.0, 24.0, 0.25) var passOutHour : float = 3.0
@export_range(0.0, 1.0) var lateRest : float = 0.75
@export_range(0.0, 1.0) var passOutRest : float = 0.5

@export_group("Warnings")
@export_range(0.0, 24.0, 0.25) var midnightHour : float = 0.0
# How many hours before each cutoff its warning comes.
@export var warnLead : float = 0.5
@export var infoColor : Color = Color(0.55, 0.75, 1.0)
@export var sleepyColor : Color = Color(0.98, 0.85, 0.4)
@export var lateColor : Color = Color(1.0, 0.62, 0.3)
@export var urgentColor : Color = Color(0.95, 0.38, 0.34)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var sleepyIcon : Texture2D
@export var urgentIcon : Texture2D

@export_group("Look")
@export_range(0.0, 1.0) var maxVignette : float = 0.75
@export var closeTime : float = 1.0
@export var passOutTime : float = 2.2
@export var openTime : float = 1.4
@export var summaryTime : float = 2.6
# Seconds between droopy blinks in the last stretch before passing out.
@export var blinkEvery : Vector2 = Vector2(2.5, 5.0)

var drowsy : ColorRect
var lids : ColorRect
var summary : Control
var sleeping : bool = false
var lastAwake : float = 0.0
var wasEmpty : bool = false
var time : float = 0.0
var warm : int = 3
var eyes : float = 0.0
var blink : float = 0.0
var blinkTimer : float = 0.0
var blinkMotion : Tween
var summaryAlpha : float = 0.0
var summaryFill : float = 0.0
var summaryTitle : String = ""
var summaryLine : String = ""
var summaryColor : Color = Color.WHITE
var summaryShare : float = 1.0
# In bed, waiting for the other player (multiplayer), and whether Esc asked
# to get up again.
var waitText : String = ""
var getUp : bool = false
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = PROCESS_MODE_ALWAYS
	var back : CanvasLayer = CanvasLayer.new()
	back.layer = 12
	add_child(back)
	drowsy = overlay(back)
	lids = overlay(self)
	summary = Control.new()
	summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.draw.connect(draw_summary)
	add_child(summary)
	lastAwake = awake_hours(cycle.time)
	blinkTimer = blinkEvery.y
	player.energy.changed.connect(check_energy)
	wasEmpty = player.energy.is_empty()

func overlay(parent : Node) -> ColorRect:
	var rect : ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = ShaderMaterial.new()
	(rect.material as ShaderMaterial).shader = preload("res://components/sleep/sleep_overlay.gdshader")
	parent.add_child(rect)
	return rect

# Hours since waking up, so the night doesn't wrap around midnight.
func awake_hours(hour : float) -> float:
	return fposmod(hour - wakeHour, 24.0)

func since(hour : float) -> bool:
	return awake_hours(cycle.time) >= awake_hours(hour)

# The share of energy a sleep right now would bring back.
func rest_share() -> float:
	if since(passOutHour):
		return passOutRest
	return lateRest if since(fullRestHour) else 1.0

# 0 until the full rest cutoff, rising to 1 at passing out.
func lateness() -> float:
	return clampf(inverse_lerp(awake_hours(fullRestHour), awake_hours(passOutHour), awake_hours(cycle.time)), 0.0, 1.0)

# Starts an hour before the full rest cutoff.
func drowsiness() -> float:
	return clampf(inverse_lerp(awake_hours(fullRestHour) - 1.0, awake_hours(passOutHour), awake_hours(cycle.time)), 0.0, 1.0)

func hour_text(hour : float) -> String:
	return "%d:%02d" % [floori(fposmod(hour, 24.0)), roundi(fmod(hour, 1.0) * 60.0)]

static func find(tree : SceneTree) -> SleepSchedule:
	return tree.get_first_node_in_group(GROUP) as SleepSchedule

# What the bed does. Returns whether the player went to sleep.
func try_sleep() -> bool:
	if sleeping:
		return false
	if not since(earliestSleepHour):
		notices.post("Not tired yet", "You can go to sleep after %s." % hour_text(earliestSleepHour), infoColor, sleepyIcon)
	elif player.handStates.currentState is PlayerHandIdleState:
		go_to_sleep()
		return true
	else:
		notices.post("Not now", "Reel in before going to sleep.", sleepyColor, sleepyIcon)
	return false

func _input(event : InputEvent) -> void:
	if sleeping:
		if not waitText.is_empty() and event.is_action_pressed("ui_cancel"):
			getUp = true
		get_viewport().set_input_as_handled()

func _process(delta : float) -> void:
	time += delta
	if not sleeping:
		check_warnings()
		if since(passOutHour):
			go_to_sleep(true)
		update_blinks(delta)
	var lateLevel : float = drowsiness()
	var breathe : float = 0.5 + 0.5 * sin(time * 1.7)
	set_overlay(drowsy, maxVignette * lateLevel * lateLevel * (0.82 + 0.18 * breathe), 0.0)
	set_overlay(lids, 0.0, maxf(eyes, blink))
	warm = maxi(warm - 1, 0)
	if summaryAlpha > 0.0 or not waitText.is_empty() or summary.has_meta("waited"):
		summary.queue_redraw()
	if waitText.is_empty():
		summary.remove_meta("waited")
	else:
		summary.set_meta("waited", true)

func set_overlay(rect : ColorRect, vignette : float, closed : float) -> void:
	rect.visible = warm > 0 or vignette > 0.002 or closed > 0.002
	if rect.visible:
		var material : ShaderMaterial = rect.material
		material.set_shader_parameter("vignette", vignette)
		material.set_shader_parameter("lids", closed)

func update_blinks(delta : float) -> void:
	var late : float = lateness()
	if late < 0.5:
		return
	blinkTimer -= delta
	if blinkTimer > 0.0:
		return
	blinkTimer = randf_range(blinkEvery.x, blinkEvery.y) * (1.5 - late)
	if blinkMotion:
		blinkMotion.kill()
	blinkMotion = create_tween().set_trans(Tween.TRANS_SINE)
	blinkMotion.tween_property(self, "blink", 0.3 + 0.35 * late, 0.35).set_ease(Tween.EASE_IN)
	blinkMotion.tween_property(self, "blink", 0.0, 0.5).set_ease(Tween.EASE_OUT)

# Posts the latest warning whose time just went by.
func check_warnings() -> void:
	var awake : float = awake_hours(cycle.time)
	if awake < lastAwake:
		lastAwake = awake
		return
	var latest : int = -1
	var hours : PackedFloat32Array = PackedFloat32Array([midnightHour, fullRestHour - warnLead, fullRestHour, passOutHour - warnLead])
	for i in hours.size():
		var at : float = awake_hours(hours[i])
		if lastAwake < at and awake >= at:
			latest = i
	lastAwake = awake
	match latest:
		0:
			notices.post("It's late", "Sleep before %s to wake up rested. %s" % [hour_text(fullRestHour), bedText], infoColor, sleepyIcon)
		1:
			notices.post("Getting sleepy", "Go to bed before %s for full energy." % hour_text(fullRestHour), sleepyColor, sleepyIcon)
		2:
			notices.post("Past %s!" % hour_text(fullRestHour), "Sleeping now only restores %d%% energy." % roundi(lateRest * 100.0), lateColor, urgentIcon)
		3:
			notices.post("About to pass out!", "At %s you collapse and wake with %d%% energy." % [hour_text(passOutHour), roundi(passOutRest * 100.0)], urgentColor, urgentIcon)

func check_energy() -> void:
	var empty : bool = player.energy.is_empty()
	if empty and not wasEmpty and not sleeping:
		notices.post("Exhausted", "Too tired to fish. %s" % bedText, urgentColor, sleepyIcon)
	wasEmpty = empty

# Closes the eyes, skips to the next morning with the energy the bedtime
# allows, shows how the night went and opens the eyes again.
func go_to_sleep(passedOut : bool = false) -> void:
	if sleeping:
		return
	sleeping = true
	player.asleep = true
	lids.mouse_filter = Control.MOUSE_FILTER_STOP
	for menu in menus:
		if menu and menu.has_method("close"):
			menu.call("close")
	var share : float = passOutRest if passedOut else rest_share()
	if blinkMotion:
		blinkMotion.kill()
	blink = 0.0
	eyes = 0.0
	var closing : Tween = create_tween().set_trans(Tween.TRANS_SINE)
	if passedOut:
		closing.tween_property(self, "eyes", 0.75, passOutTime * 0.4).set_ease(Tween.EASE_IN)
		closing.tween_property(self, "eyes", 0.45, passOutTime * 0.2).set_ease(Tween.EASE_OUT)
		closing.tween_property(self, "eyes", 1.0, passOutTime * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		closing.tween_property(self, "eyes", 1.0, closeTime).set_ease(Tween.EASE_IN_OUT)
	await closing.finished
	# With a friend, the night only comes once both are in bed.
	var session : NetSession = NetSession.find(get_tree())
	if session and session.online():
		session.lie_down(true)
		getUp = false
		while session.online() and not session.nightReady:
			waitText = "Waiting for %s to go to bed..." % session.waiting_for()
			if getUp and not passedOut:
				waitText = ""
				session.lie_down(false)
				await open_eyes()
				return
			await get_tree().process_frame
		waitText = ""
		session.nightReady = false
	if not Net.has_company():
		get_tree().paused = true
	notices.clear()
	player.wake_reset()
	var nextDay : bool = cycle.time >= wakeHour
	cycle.set_time(wakeHour)
	if nextDay:
		cycle.set_day(cycle.day + 1)
	lastAwake = 0.0
	player.refresh_energy_max()
	player.energy.refill(share)
	player.progress.count("days")
	slept_night.emit()
	# Passed out somewhere: Pip found you and brought you home.
	var world : World = World.find(get_tree())
	if passedOut and world:
		world.wake_at_home()
	var saved : bool = SaveGame.save_game(get_tree())
	summaryTitle = "%s, day %d" % [cycle.weekday_name(), cycle.day]
	summaryShare = share
	if passedOut:
		summaryLine = "You passed out!"
		summaryColor = urgentColor
	elif share < 1.0:
		summaryLine = "You stayed up late."
		summaryColor = lateColor
	else:
		summaryLine = "You slept well."
		summaryColor = goodColor
	if saved:
		summaryLine += " Game saved."
	summaryFill = 0.0
	var shown : Tween = create_tween().set_parallel()
	shown.tween_method(set_summary.bind(true), 0.0, 1.0, 0.4)
	shown.tween_method(set_summary.bind(false), 0.0, share, 0.9).set_delay(0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(summaryTime).timeout
	var hidden : Tween = create_tween()
	hidden.tween_method(set_summary.bind(true), 1.0, 0.0, 0.35)
	await hidden.finished
	get_tree().paused = false
	await open_eyes()
	slept.emit(share)
	if passedOut:
		rescued()

# Pip has a word about it after the player wakes in front of their house.
const RESCUE_LINES : PackedStringArray = [
	"Found you face down by the water again. You snore like a foghorn, you know that?",
	"Carried you home myself. My back would like a word with you.",
	"Bed. Is. Inside. The house. I am too old to be hauling anglers up the hill.",
	"You were asleep on a crate of mackerel. The mackerel did not mind. I did.",
]

func rescued() -> void:
	var talk : DialogueUI = DialogueUI.find(get_tree())
	if talk and not talk.busy():
		talk.say("pip", RESCUE_LINES[randi() % RESCUE_LINES.size()], PackedStringArray())

func open_eyes() -> void:
	var opening : Tween = create_tween().set_trans(Tween.TRANS_SINE)
	opening.tween_property(self, "eyes", 0.4, openTime * 0.4).set_ease(Tween.EASE_OUT)
	opening.tween_property(self, "eyes", 0.6, openTime * 0.2).set_ease(Tween.EASE_IN_OUT)
	opening.tween_property(self, "eyes", 0.0, openTime * 0.4).set_ease(Tween.EASE_IN_OUT)
	await opening.finished
	sleeping = false
	player.asleep = false
	lids.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_summary(amount : float, alpha : bool) -> void:
	if alpha:
		summaryAlpha = amount
	else:
		summaryFill = amount
	summary.queue_redraw()

func draw_summary() -> void:
	var font : Font = ui.font
	if not waitText.is_empty():
		var y : float = summary.size.y * 0.5
		summary.draw_string(font, Vector2(0.0, y), waitText, HORIZONTAL_ALIGNMENT_CENTER, summary.size.x, 4, ui.textColor)
		summary.draw_string(font, Vector2(0.0, y + 8.0), "Esc: get up", HORIZONTAL_ALIGNMENT_CENTER, summary.size.x, 3, ui.dimColor)
		return
	if summaryAlpha <= 0.0:
		return
	var middle : Vector2 = (summary.size * 0.5).floor()
	var fade : Color = Color(1.0, 1.0, 1.0, summaryAlpha)
	if sleepyIcon:
		var bob : float = sin(time * 2.0) * 1.5
		var drawn : Vector2 = sleepyIcon.get_size() * 2.0
		summary.draw_texture_rect(sleepyIcon, Rect2(Vector2(middle.x - drawn.x * 0.5, middle.y - 40.0 + bob), drawn), false, fade)
	summary.draw_string(font, Vector2(0.0, middle.y - 5.0), summaryTitle, HORIZONTAL_ALIGNMENT_CENTER, summary.size.x, 8, ui.textColor * fade)
	summary.draw_string(font, Vector2(0.0, middle.y + 5.0), summaryLine, HORIZONTAL_ALIGNMENT_CENTER, summary.size.x, 4, summaryColor * fade)
	var bar : Rect2 = Rect2(middle.x - 30.0, middle.y + 11.0, 60.0, 5.0)
	summary.draw_rect(bar, ui.frameColor * fade)
	summary.draw_rect(bar.grow(-1.0), ui.slotColor * fade)
	var inner : Rect2 = bar.grow(-1.0)
	var filled : float = roundf(inner.size.x * summaryFill)
	if filled > 0.0:
		var color : Color = summaryColor
		summary.draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), color * fade)
		summary.draw_rect(Rect2(inner.position, Vector2(filled, 1.0)), color.lightened(0.4) * fade)
	summary.draw_string(font, Vector2(0.0, bar.end.y + 6.0), "Energy %d%%" % roundi(summaryFill * 100.0), HORIZONTAL_ALIGNMENT_CENTER, summary.size.x, 3, ui.dimColor * fade)
