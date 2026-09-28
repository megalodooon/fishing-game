extends Control
class_name EnergyBar

# The player's energy as a vertical bar in the bottom right corner. What was
# just spent lingers as a pale trail before it drains away, gains flash, and
# the bar pulses when it's nearly empty. Hovering it shows the numbers and
# how much a sleep right now would restore.

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var sleep : SleepSchedule
@export var bolt : Texture2D

@export_group("Layout")
@export var barSize : Vector2i = Vector2i(9, 46)
@export var margin : int = 2

@export_group("Look")
# Fill color from empty (left) to full (right).
@export var fill : Gradient
@export var trailColor : Color = Color(1.0, 0.96, 0.86, 0.85)
@export var lowColor : Color = Color(0.95, 0.38, 0.34)
@export_range(0.0, 1.0) var lowShare : float = 0.2
@export var followSpeed : float = 10.0
@export var trailDelay : float = 0.4
@export var trailSpeed : float = 5.0

var energy : Energy
var barRect : Rect2
var shown : float = 1.0
var trail : float = 1.0
var trailWait : float = 0.0
var flash : float = 0.0
var hovered : bool = false
var time : float = 0.0
var mouse : Vector2 = Vector2.ZERO
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_TOP_LEFT)
	if not fill:
		fill = Gradient.new()
		fill.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		fill.colors = PackedColorArray([Color(0.93, 0.33, 0.3), Color(0.98, 0.82, 0.32), Color(0.42, 0.86, 0.4)])
	energy = player.energy
	energy.changed.connect(on_changed)
	shown = energy.fraction()
	trail = shown
	ui.laid_out.connect(fit)
	fit()

func fit() -> void:
	scale = ui.scale
	size = ui.size
	barRect = Rect2(Vector2(size.x - margin - barSize.x, size.y - margin - barSize.y).floor(), barSize)
	queue_redraw()

func _has_point(point : Vector2) -> bool:
	return barRect.grow(1.0).has_point(point)

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hovered = false
		queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		hovered = true
		queue_redraw()

func on_changed() -> void:
	var target : float = energy.fraction()
	if target < shown:
		trail = maxf(trail, shown)
		shown = target
		trailWait = trailDelay
	elif target > shown:
		flash = 1.0

func _process(delta : float) -> void:
	time += delta
	var target : float = energy.fraction()
	shown = lerpf(shown, target, 1.0 - exp(-followSpeed * delta)) if target > shown else target
	if trailWait > 0.0:
		trailWait -= delta
	else:
		trail = maxf(lerpf(trail, shown, 1.0 - exp(-trailSpeed * delta)), shown)
	flash = maxf(flash - delta * 2.5, 0.0)
	if hovered or flash > 0.0 or trail - shown > 0.001 or absf(target - shown) > 0.001 or target <= lowShare:
		queue_redraw()

func _draw() -> void:
	var low : float = 0.5 + 0.5 * sin(time * TAU * 1.3) if energy.fraction() <= lowShare else 0.0
	draw_rect(barRect, ui.frameColor.lerp(lowColor, low * 0.8))
	draw_rect(barRect.grow(-1.0), ui.panelColor)
	var iconHeight : float = float(bolt.get_height()) if bolt else 0.0
	var track : Rect2 = Rect2(barRect.position + Vector2(2.0, 2.0), Vector2(barRect.size.x - 4.0, barRect.size.y - 5.0 - iconHeight))
	draw_rect(track, ui.slotColor)
	var trailHeight : float = roundf(track.size.y * trail)
	var fillHeight : float = roundf(track.size.y * shown)
	if trailHeight > fillHeight:
		draw_rect(Rect2(track.position.x, track.end.y - trailHeight, track.size.x, trailHeight - fillHeight), trailColor)
	if fillHeight > 0.0:
		var color : Color = fill.sample(shown).lerp(Color.WHITE, flash * 0.6 + low * 0.25)
		var area : Rect2 = Rect2(track.position.x, track.end.y - fillHeight, track.size.x, fillHeight)
		draw_rect(area, color)
		draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), color.lightened(0.3))
		draw_rect(Rect2(area.position, Vector2(area.size.x, 1.0)), color.lightened(0.45))
		draw_rect(Rect2(area.end.x - 1.0, area.position.y, 1.0, area.size.y), color.darkened(0.2))
	if bolt:
		var pulse : float = 1.0 + low * 0.25
		var shownSize : Vector2 = bolt.get_size() * pulse
		var center : Vector2 = Vector2(barRect.get_center().x, barRect.end.y - 1.0 - bolt.get_height() * 0.5)
		draw_texture_rect(bolt, Rect2(center - shownSize * 0.5, shownSize), false)
	if hovered:
		var lines : PackedStringArray = PackedStringArray(["Now", "%d/%d" % [ceili(energy.value), roundi(energy.maximum)]])
		if sleep:
			lines.append_array(["Sleep now", "%d%%" % roundi(sleep.rest_share() * 100.0)])
		ui.paint_tip(self, mouse, "Energy", ui.textColor, lines, ui.tip_size("Energy", lines))
