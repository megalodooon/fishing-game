extends MenuPanel
class_name WorldMapUI

# The sea chart, opened with M. Every place in the player's Atlas sits on a
# shaded sea that scrolls sideways (mouse wheel, A/D, dragging or the edge
# arrows). Clicking a place shows what the trip there costs. Sailing moves
# the little boat across the chart while the clock runs and the energy
# drains, and the new place loads behind the chart before it fades away.
# The boat always waits beside a place, on the side it came in from, and the
# route runs from there to the facing side of the next one.
# Locked places show what they still need and are unlocked from the same card.

enum Zone { NONE, PLACE, CARD, ACTION, ACTION2, CLOSE, LEFT, RIGHT }

const GROUP : StringName = &"world_maps"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var world : World
@export var cycle : DayNightCycle
@export var sleep : SleepSchedule
@export var notices : NoticeBoard
# Closed when the chart opens.
@export var menus : Array[Control] = []
# The world under the chart. It isn't drawn while the chart covers the whole
# screen (it keeps running), as none of it would show.
@export var covered : Array[Node] = []

@export_group("Art")
@export var boatIcon : Texture2D
@export var playerIcon : Texture2D
@export var lockIcon : Texture2D
@export var coinIcon : Texture2D
@export var energyIcon : Texture2D

@export_group("Text")
@export var title : String = "Sea Chart"
@export var mapKeyText : String = "M"

@export_group("Travel")
# Chart pixels per second the little boat sails, within sailTime seconds.
@export var sailSpeed : float = 40.0
@export var sailTime : Vector2 = Vector2(1.2, 4.5)
@export var arriveDelay : float = 0.4
# Chart pixels kept between the waiting boat and a place's icon and name.
@export var berthGap : float = 1.0

@export_group("Water")
# The sea's shader (chart_water.gdshader). The colors below are baked into
# it once, so changing them needs a restart.
@export var water : ShaderMaterial
@export var shallowColor : Color = Color(0.18, 0.62, 0.78)
@export var deepColor : Color = Color(0.04, 0.17, 0.36)
# Chart pixels from an island's shore where the water starts getting deeper,
# and where it's fully deep.
@export var shallowReach : Vector2 = Vector2(2.0, 34.0)
# A place's chartTint is full within the first distance and gone by the second.
@export var tintReach : Vector2 = Vector2(8.0, 46.0)
# Chart pixels per baked texel. The shader smooths between them.
@export var fieldTexel : float = 4.0

@export_group("Layout")
@export var barHeight : int = 11
@export var edge : int = 2
@export var buttonSize : int = 7
@export var cardWidth : int = 86
@export var cardPadding : int = 3
@export var actionHeight : int = 9
@export var scrollSpeed : float = 110.0
@export var wheelStep : float = 24.0

@export_group("Colors")
# Under the chart when there's no water shader.
@export var seaColor : Color = Color(0.2, 0.5, 0.66)
@export var routeColor : Color = Color(1.0, 0.97, 0.85, 0.9)
@export var lockedTint : Color = Color(0.5, 0.55, 0.65)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var infoColor : Color = Color(0.55, 0.75, 1.0)

var atlas : Atlas
var clip : Control
var sea : ColorRect
var chart : Control
var overlay : Control
var viewRect : Rect2
var barRect : Rect2
var closeRect : Rect2
var leftRect : Rect2
var rightRect : Rect2
var cardRect : Rect2
var actionRect : Rect2
# The card's second button (boarding a friend's boat).
var action2Rect : Rect2
var scroll : float = 0.0
var scrollGoal : float = 0.0
var selected : Location
var hovered : Location
var zone : Zone = Zone.NONE
var mouse : Vector2 = Vector2.ZERO
var pressedAt : Variant = null
var pressScroll : float = 0.0
var dragging : bool = false
var time : float = 0.0
# What the selected place's card shows, rebuilt every frame while open.
var card : Dictionary = {}
var wrapped : Dictionary = {}
# The trip under way: the place, the path the boat takes on the chart and how
# long it is, the energy and hours it costs in total and how many seconds it
# takes.
var trip : Dictionary = {}
var tripDone : float = 0.0
var boatFacing : float = 1.0
var heading : Vector2 = Vector2.ZERO
# Routes from where the boat waits, by place, until the chart next opens.
var routes : Dictionary = {}
var covering : bool = false
# What the card's spot was last worked out for.
var cardKey : Array = []
# The hub's strip stands in for the title bar.
var hubbed : bool = false
var paper : MenuSkin = preload("res://ui/skins/themes/paper.tres")
#------------------------#


static func find(tree : SceneTree) -> WorldMapUI:
	return tree.get_first_node_in_group(GROUP) as WorldMapUI

func _ready() -> void:
	super()
	add_to_group(GROUP)
	slide = Vector2.ZERO
	set_anchors_preset(PRESET_TOP_LEFT)
	atlas = player.atlas
	clip = Control.new()
	clip.mouse_filter = MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	add_child(clip)
	sea = ColorRect.new()
	sea.mouse_filter = MOUSE_FILTER_IGNORE
	sea.color = seaColor
	sea.material = water
	clip.add_child(sea)
	chart = canvas(clip, draw_chart)
	overlay = canvas(self, draw_overlay)
	ui.laid_out.connect(fit)
	fit()
	bake_water()

func canvas(parent : Control, drawer : Callable) -> Control:
	var child : Control = Control.new()
	child.mouse_filter = MOUSE_FILTER_IGNORE
	child.draw.connect(drawer)
	parent.add_child(child)
	return child

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	hubbed = MenuHub.find(get_tree()) != null if is_inside_tree() else false
	var bar : float = MenuHub.HEIGHT if hubbed else float(barHeight)
	barRect = Rect2(0.0, 0.0, size.x, bar)
	viewRect = Rect2(edge, bar, size.x - edge * 2.0, size.y - bar - edge)
	clip.position = viewRect.position
	clip.size = viewRect.size
	sea.size = viewRect.size
	chart.size = viewRect.size
	overlay.size = size
	closeRect = Rect2() if hubbed else Rect2(size.x - edge - buttonSize, floorf((barHeight - buttonSize) * 0.5), buttonSize, buttonSize)
	var middle : float = floorf(viewRect.get_center().y)
	leftRect = Rect2(viewRect.position.x + 1.0, middle - 5.0, 6.0, 10.0)
	rightRect = Rect2(viewRect.end.x - 7.0, middle - 5.0, 6.0, 10.0)
	scrollGoal = clampf(scrollGoal, 0.0, max_scroll())
	scroll = clampf(scroll, 0.0, max_scroll())

func hub_open() -> void:
	if not shown:
		try_open()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

# While the chart is up it takes every key, so nothing behind it reacts. The
# mouse goes to the chart itself, which covers the whole screen.
func _input(event : InputEvent) -> void:
	if not shown or event is InputEventMouse or (trip.is_empty() and MenuHub.is_hub_key(get_tree(), event)):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close()

func try_open() -> void:
	if player.asleep:
		return
	if not player.handStates.currentState is PlayerHandIdleState:
		notices.post("Not now", "Reel in before looking at the chart.", infoColor)
		return
	for menu in menus:
		if menu and menu.has_method("close"):
			menu.call("close")
	atlas.discount = clampf(player.stat(&"travelDiscount") * 0.01, 0.0, 0.6)
	routes.clear()
	selected = null
	hovered = null
	zone = Zone.NONE
	scrollGoal = clampf(boat_position().x - viewRect.size.x * 0.5, 0.0, max_scroll())
	scroll = scrollGoal
	player.charting = true
	open_menu()

# Stops or starts drawing the covered world. Only its drawing is switched
# off, straight in the renderer, so the nodes' own visibility (which the game
# changes, like stowing the boat) is left alone and put back as it is.
func cover(on : bool) -> void:
	if on == covering:
		return
	covering = on
	for node in covered:
		for item in canvas_items(node):
			RenderingServer.canvas_item_set_visible(item.get_canvas_item(), item.visible and not on)

# The node itself, or the canvas items under a layer or a plain node.
func canvas_items(node : Node) -> Array[CanvasItem]:
	var list : Array[CanvasItem] = []
	if node is CanvasItem:
		list.append(node)
	elif node:
		for child in node.get_children():
			list.append_array(canvas_items(child))
	return list

func close() -> void:
	if shown and trip.is_empty():
		close_menu()
		cover(false)
		player.charting = false
		pressedAt = null
		dragging = false

func _has_point(_point : Vector2) -> bool:
	return shown

func max_scroll() -> float:
	return maxf(atlas.chart_width() - viewRect.size.x, 0.0)

# Chart pixels to chart-canvas pixels.
func chart_origin() -> Vector2:
	return Vector2(-roundf(scroll), floorf((viewRect.size.y - atlas.mapSize.y) * 0.5))

func to_view(point : Vector2) -> Vector2:
	return viewRect.position + chart_origin() + point

func icon_size(location : Location) -> Vector2:
	return location.mapIcon.get_size() if location.mapIcon else Vector2(16.0, 12.0)

func place_rect(location : Location) -> Rect2:
	var extent : Vector2 = icon_size(location)
	return Rect2((to_view(location.mapPosition) - extent * 0.5).round(), extent)

func boat_position() -> Vector2:
	if not trip.is_empty():
		return along(trip.path, cruise(tripDone) * trip.length)[0]
	return rest_point() if atlas.current else Vector2.ZERO

func trip_fraction() -> float:
	return tripDone

# How far along the route the boat is at this share of the trip's time: it
# speeds up over the first fifth, sails at an even speed, and slows down to
# the berth over the last fifth.
static func cruise(t : float) -> float:
	const RAMP : float = 0.2
	var top : float = 1.0 / (1.0 - RAMP)
	t = clampf(t, 0.0, 1.0)
	if t < RAMP:
		return top * t * t / (2.0 * RAMP)
	if t > 1.0 - RAMP:
		return 1.0 - top * (1.0 - t) * (1.0 - t) / (2.0 * RAMP)
	return top * (t - RAMP * 0.5)

# A place's name under its icon, in chart pixels.
func label_rect(location : Location) -> Rect2:
	var extent : Vector2 = icon_size(location)
	var center : Vector2 = location.mapPosition.round()
	var width : float = ui.font.get_string_size(location.displayName, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 2.0
	return Rect2(center.x - width * 0.5, center.y + extent.y * 0.5 + 1.0, width, ui.statSize + 3.0)

# Where a boat coming from a point stops at a place: as close as it gets on
# the line between them without covering the place's icon (an oval) or name.
func berth(location : Location, toward : Vector2) -> Vector2:
	var center : Vector2 = location.mapPosition.round()
	var direction : Vector2 = (toward - center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var radius : Vector2 = icon_size(location) * 0.5 + Vector2(berthGap, berthGap)
	var label : Rect2 = label_rect(location).grow(berthGap)
	var hull : Rect2 = boat_box()
	var reach : float = 0.0
	while reach < 80.0:
		var box : Rect2 = Rect2(center + direction * reach + hull.position, hull.size)
		var nearest : Vector2 = (center.clamp(box.position, box.end) - center) / radius
		if nearest.length_squared() >= 1.0 and not box.intersects(label):
			break
		reach += 0.5
	return (center + direction * reach).round()

# The chart pixels the boat and its sailor cover around the boat's position,
# with room for the rocking.
func boat_box() -> Rect2:
	var half : float = (float(boatIcon.get_width()) if boatIcon else 13.0) * 0.5
	var above : float = (float(playerIcon.get_height()) if playerIcon else 6.0) + 0.5
	var below : float = (float(boatIcon.get_height()) - 2.0 if boatIcon else 3.0) + 0.5
	return Rect2(-half, -above, half * 2.0, above + below)

# Where the boat waits at the current place: on the side it sailed in from.
func rest_point() -> Vector2:
	return berth(atlas.current, rest_toward())

func rest_toward() -> Vector2:
	var from : Location = atlas.previous
	return from.mapPosition if from and from != atlas.current else atlas.current.mapPosition + Vector2(20.0, 3.0)

# The way from the waiting boat to a place: around the current place to the
# side facing it, then straight across to the side of the place facing back,
# so the boat never sails over either of them.
func route(to : Location) -> PackedVector2Array:
	if routes.has(to):
		return routes[to]
	var here : Location = atlas.current
	var center : Vector2 = here.mapPosition.round()
	var start : float = (rest_toward() - center).angle()
	var sweep : float = wrapf((to.mapPosition - center).angle() - start, -PI, PI)
	var steps : int = ceili(absf(sweep) / (PI / 4.0))
	var corners : PackedVector2Array = PackedVector2Array([rest_point()])
	for i in range(1, steps + 1):
		corners.append(berth(here, center + Vector2.from_angle(start + sweep * i / steps) * 100.0))
	corners.append(berth(to, here.mapPosition))
	var path : PackedVector2Array = smooth(corners)
	routes[to] = path
	return path

# A curve through the corners (Catmull-Rom), as points about a pixel apart, so
# the boat glides around the island it leaves instead of turning sharply.
static func smooth(corners : PackedVector2Array) -> PackedVector2Array:
	if corners.size() < 3:
		return corners
	var out : PackedVector2Array = PackedVector2Array([corners[0]])
	for i in corners.size() - 1:
		var p0 : Vector2 = corners[maxi(i - 1, 0)]
		var p1 : Vector2 = corners[i]
		var p2 : Vector2 = corners[i + 1]
		var p3 : Vector2 = corners[mini(i + 2, corners.size() - 1)]
		var steps : int = maxi(ceili(p1.distance_to(p2)), 1)
		for j in range(1, steps + 1):
			var t : float = float(j) / steps
			var t2 : float = t * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t))
	return out

static func path_length(path : PackedVector2Array) -> float:
	var length : float = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length

# The point that far along a path, and which way the path runs there.
static func along(path : PackedVector2Array, distance : float) -> Array[Vector2]:
	for i in range(1, path.size()):
		var step : float = path[i - 1].distance_to(path[i])
		if distance <= step or i == path.size() - 1:
			var direction : Vector2 = (path[i] - path[i - 1]) / step if step > 0.0 else Vector2.ZERO
			return [path[i - 1] + direction * clampf(distance, 0.0, step), direction]
		distance -= step
	return [path[0], Vector2.ZERO]

# Bakes the sea's colors for the shader: shallow around the islands, deep
# between them, and tinted around places with a chartTint.
func bake_water() -> void:
	if not water:
		return
	var cells : Vector2i = Vector2i(ceili(atlas.chart_width() / fieldTexel) + 1, ceili(atlas.mapSize.y / fieldTexel) + 1)
	var image : Image = Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var shores : Array[Rect2] = []
	var tinted : Array[Location] = []
	for location in atlas.locations:
		if location.is_island():
			var extent : Vector2 = icon_size(location) * 0.6
			shores.append(Rect2(location.mapPosition - extent * 0.5, extent))
		if location.chartTint.a > 0.0:
			tinted.append(location)
	for y in cells.y:
		for x in cells.x:
			var at : Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * fieldTexel
			var shore : float = INF
			for rect in shores:
				shore = minf(shore, Vector2(maxf(maxf(rect.position.x - at.x, at.x - rect.end.x), 0.0), maxf(maxf(rect.position.y - at.y, at.y - rect.end.y), 0.0)).length())
			var depth : float = smoothstep(shallowReach.x, shallowReach.y, shore)
			var color : Color = shallowColor.lerp(deepColor, depth)
			for location in tinted:
				var near : float = 1.0 - smoothstep(tintReach.x, tintReach.y, at.distance_to(location.mapPosition))
				if near > 0.0:
					var tint : Color = location.chartTint * lerpf(1.25, 0.7, depth)
					color = color.lerp(Color(tint.r, tint.g, tint.b), near * location.chartTint.a)
			color.a = (1.0 - depth) * (1.0 - depth)
			image.set_pixel(x, y, color)
	water.set_shader_parameter(&"field", ImageTexture.create_from_image(image))
	water.set_shader_parameter(&"field_size", Vector2(cells) * fieldTexel)

func _process(delta : float) -> void:
	if not visible:
		return
	cover(shown and modulate.a >= 1.0)
	time += delta
	if not trip.is_empty():
		advance_trip(delta)
	elif shown:
		var axis : float = Input.get_axis("left", "right")
		if axis != 0.0:
			scrollGoal = clampf(scrollGoal + axis * scrollSpeed * delta, 0.0, max_scroll())
	scroll = lerpf(scroll, scrollGoal, 1.0 - exp(-14.0 * delta))
	if absf(scroll - scrollGoal) < 0.05:
		scroll = scrollGoal
	update_card()
	if water:
		water.set_shader_parameter(&"origin", -chart_origin())
	queue_redraw()
	chart.queue_redraw()
	overlay.queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouse:
		mouse = event.position
	if event is InputEventMouseMotion:
		if pressedAt != null and trip.is_empty():
			var moved : float = mouse.x - (pressedAt as Vector2).x
			if not dragging and absf(moved) > 2.0:
				dragging = true
			if dragging:
				scrollGoal = clampf(pressScroll - moved, 0.0, max_scroll())
				scroll = scrollGoal
		hover_at(mouse)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					pressedAt = mouse
					pressScroll = scrollGoal
					dragging = false
				else:
					if not dragging and pressedAt != null:
						click()
					pressedAt = null
					dragging = false
			MOUSE_BUTTON_RIGHT:
				if event.pressed and trip.is_empty():
					if selected:
						select(null)
					else:
						close()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				if event.pressed and trip.is_empty():
					scrollGoal = clampf(scrollGoal - wheelStep, 0.0, max_scroll())
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				if event.pressed and trip.is_empty():
					scrollGoal = clampf(scrollGoal + wheelStep, 0.0, max_scroll())
		hover_at(mouse)
	accept_event()

func hover_at(point : Vector2) -> void:
	hovered = null
	zone = Zone.NONE
	if not trip.is_empty():
		return
	if closeRect.has_point(point):
		zone = Zone.CLOSE
	elif selected and cardRect.has_point(point):
		zone = Zone.ACTION if actionRect.has_point(point) else (Zone.ACTION2 if action2Rect.has_point(point) else Zone.CARD)
	elif scrollGoal > 0.0 and leftRect.has_point(point):
		zone = Zone.LEFT
	elif scrollGoal < max_scroll() and rightRect.has_point(point):
		zone = Zone.RIGHT
	elif viewRect.has_point(point):
		for i in range(atlas.locations.size() - 1, -1, -1):
			if place_rect(atlas.locations[i]).grow(2.0).has_point(point):
				hovered = atlas.locations[i]
				zone = Zone.PLACE
				return

func click() -> void:
	if not trip.is_empty():
		return
	match zone:
		Zone.CLOSE:
			close()
		Zone.LEFT:
			scrollGoal = clampf(scrollGoal - viewRect.size.x * 0.5, 0.0, max_scroll())
		Zone.RIGHT:
			scrollGoal = clampf(scrollGoal + viewRect.size.x * 0.5, 0.0, max_scroll())
		Zone.ACTION:
			act()
		Zone.ACTION2:
			if card.get("enabled2", false):
				var session : NetSession = NetSession.find(get_tree())
				if session:
					session.ask_to_board(card.friend)
					update_card()
		Zone.PLACE:
			select(null if hovered == selected else hovered)
		Zone.NONE:
			select(null)

func select(location : Location) -> void:
	selected = location
	update_card()
	hover_at(mouse)

func act() -> void:
	if not selected or not card.get("enabled", false):
		return
	var session : NetSession = NetSession.find(get_tree())
	if selected == atlas.current and session and session.boardedOn > 0:
		session.unboard()
		update_card()
		return
	if atlas.is_unlocked(selected):
		sail(selected)
	elif atlas.unlock(selected, player.journal, player.wallet, player.progress):
		notices.post("Unlocked!", "%s is on the chart now." % selected.displayName, goodColor)
		update_card()

func too_late(hours : float) -> bool:
	return sleep != null and sleep.awake_hours(cycle.time) + hours >= sleep.awake_hours(sleep.passOutHour)

# Sails straight off to a place, like when a friend said yes to boarding.
func sail_to(to : Location) -> void:
	if not shown:
		try_open()
	if shown and trip.is_empty():
		sail(to)

func sail(to : Location) -> void:
	var session : NetSession = NetSession.find(get_tree())
	if session and session.boardedOn > 0:
		session.unboard()
	var path : PackedVector2Array = route(to)
	var length : float = path_length(path)
	trip = {
		"to": to, "path": path, "length": length,
		"energy": atlas.energy_cost(to), "hours": atlas.travel_hours(to),
		"seconds": clampf(length / sailSpeed, sailTime.x, sailTime.y),
	}
	tripDone = 0.0
	turn(along(path, 0.0)[1])
	selected = null
	hovered = null
	zone = Zone.NONE

# The clock and the energy follow the boat along, so the trip costs exactly
# what the card said by the time it arrives.
func advance_trip(delta : float) -> void:
	if tripDone >= 1.0:
		return
	var before : float = tripDone
	tripDone = minf(tripDone + delta / trip.seconds, 1.0)
	var part : float = tripDone - before
	# With a friend the clock is shared, so trips don't skip it.
	if not Net.has_company():
		cycle.advance(trip.hours * part)
	if trip.energy > 0.0:
		player.energy.spend(trip.energy * part)
	var at : Array[Vector2] = along(trip.path, cruise(tripDone) * trip.length)
	turn(at[1])
	scrollGoal = clampf(at[0].x - viewRect.size.x * 0.5, 0.0, max_scroll())
	if tripDone >= 1.0:
		heading = Vector2.ZERO
		arrive()

# Faces the boat the way it's sailing, unless that's nearly straight up or down.
func turn(direction : Vector2) -> void:
	heading = direction
	if absf(direction.x) > 0.25:
		boatFacing = signf(direction.x)

func arrive() -> void:
	await get_tree().create_timer(arriveDelay).timeout
	Skills.add(player, Skills.SAILING, trip.length * 0.6)
	player.progress.count("trips")
	world.arrive(trip.to)
	trip = {}
	close()

func hours_text(hours : float) -> String:
	var minutes : int = roundi(hours * 60.0)
	@warning_ignore("integer_division")
	var whole : int = minutes / 60
	if whole == 0:
		return "%dm" % minutes
	return "%dh" % whole if minutes % 60 == 0 else "%dh%02d" % [whole, minutes % 60]

func clock_text(hour : float) -> String:
	var minutes : int = roundi(fposmod(hour, 24.0) * 60.0) % (24 * 60)
	@warning_ignore("integer_division")
	return "%d:%02d" % [minutes / 60, minutes % 60]

# The rows the selected place's card shows and what its button does.
func card_info(location : Location) -> Dictionary:
	var rows : Array = []
	var action : String = ""
	var enabled : bool = false
	var session : NetSession = NetSession.find(get_tree())
	var friends : Array = friends_at(location)
	if location == atlas.current:
		action = "You are here"
		if session and session.boardedOn > 0:
			action = "Leave %s's boat" % Net.name_of(session.boardedOn)
			enabled = true
	elif atlas.is_unlocked(location):
		var energy : float = atlas.energy_cost(location)
		var hours : float = atlas.travel_hours(location)
		rows.append(["Energy", "Free" if energy <= 0.0 else "%d" % energy, goodColor if energy <= 0.0 else ui.textColor])
		if Net.has_company():
			rows.append(["Time", "Shared clock", ui.dimColor])
		else:
			rows.append(["Time", hours_text(hours), ui.textColor])
			rows.append(["Arrive", clock_text(cycle.time + hours), ui.textColor])
		if player.energy.value < energy:
			action = "Too tired"
		elif too_late(hours):
			action = "Too late"
		else:
			action = "Sail"
			enabled = true
	else:
		for need in atlas.missing(location, player.journal, player.progress):
			rows.append([need[0], need[1], ui.blockedColor])
		if location.coinCost > 0:
			rows.append(["Cost", "%d" % location.coinCost, ui.textColor if player.wallet.can_afford(location.coinCost) else ui.blockedColor])
		action = "Unlock"
		enabled = atlas.can_unlock(location, player.journal, player.wallet, player.progress)
	# Friends here, and a button to ask to ride on their boat.
	var action2 : String = ""
	var enabled2 : bool = false
	for id in friends:
		rows.append(["Here", Net.name_of(id), Color(0.55, 0.78, 1.0)])
	if session and not location.is_island() and atlas.is_unlocked(location) and not friends.is_empty():
		var friend : int = friends[0]
		var state : Dictionary = session.states.get(friend, {})
		if session.boardedOn != friend and state.get("board", 0) == 0 and state.get("at", "") == location.scene:
			action2 = "Board"
			enabled2 = session.boardAsked == 0 and session.boardedOn == 0
	return {"rows": rows, "action": action, "enabled": enabled, "action2": action2, "enabled2": enabled2, "friend": friends[0] if not friends.is_empty() else 0}

# Other players at this place (not out sailing), by peer id.
func friends_at(location : Location) -> Array:
	var session : NetSession = NetSession.find(get_tree())
	var list : Array = []
	if session and location:
		for id in session.states:
			var state : Dictionary = session.states[id]
			if state.get("loc", "") == location.resource_path and not state.has("trip"):
				list.append(id)
	return list

func description_lines(location : Location) -> PackedStringArray:
	if not wrapped.has(location):
		wrapped[location] = ui.wrap_lines(location.description, cardWidth - cardPadding * 2.0, ui.statSize) if not location.description.is_empty() else PackedStringArray()
	return wrapped[location]

# Goes where it covers the least of the place, the boat and the route: beside
# the place, over or under it, or in a corner of the chart.
func update_card() -> void:
	if not selected:
		card = {}
		cardRect = Rect2()
		actionRect = Rect2()
		action2Rect = Rect2()
		return
	card = card_info(selected)
	var lines : int = description_lines(selected).size() + card.rows.size()
	var height : float = cardPadding * 2.0 + ui.titleSize + 2.0 + lines * (ui.statSize + 1.0) + 2.0 + actionHeight
	var extent : Vector2 = Vector2(cardWidth, height)
	var icon : Rect2 = place_rect(selected)
	var hull : Rect2 = boat_box()
	var boat : Rect2 = Rect2(to_view(boat_position()) + hull.position, hull.size)
	# Where it goes only changes with these, so it's worked out once for them.
	var key : Array = [selected, icon, boat, extent, viewRect, atlas.current, atlas.is_unlocked(selected)]
	if key != cardKey:
		cardKey = key
		cardRect = card_spot(icon, boat, extent)
	var width : float = ui.font.get_string_size(card.action, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 8.0
	actionRect = Rect2((cardRect.end - Vector2(width + cardPadding, actionHeight + cardPadding)).round(), Vector2(roundf(width), actionHeight))
	action2Rect = Rect2()
	if not String(card.get("action2", "")).is_empty():
		var width2 : float = roundf(ui.font.get_string_size(card.action2, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 8.0)
		action2Rect = Rect2(actionRect.position - Vector2(width2 + 2.0, 0.0), Vector2(width2, actionHeight))

func card_spot(icon : Rect2, boat : Rect2, extent : Vector2) -> Rect2:
	var dots : PackedVector2Array = PackedVector2Array()
	if selected != atlas.current and atlas.is_unlocked(selected):
		var path : PackedVector2Array = route(selected)
		var length : float = path_length(path)
		var at : float = 0.0
		while at < length:
			dots.append(to_view(along(path, at)[0]))
			at += 3.0
	var low : Vector2 = Vector2(leftRect.end.x + 1.0, viewRect.position.y + 1.0)
	var high : Vector2 = Vector2(rightRect.position.x - 1.0, viewRect.end.y - 1.0) - extent
	var middle : Vector2 = icon.get_center() - extent * 0.5
	var spots : PackedVector2Array = PackedVector2Array([
		Vector2(icon.end.x + 4.0, middle.y), Vector2(icon.position.x - 4.0 - cardWidth, middle.y),
		Vector2(middle.x, icon.end.y + 8.0), Vector2(middle.x, icon.position.y - 2.0 - extent.y),
		low, high, Vector2(low.x, high.y), Vector2(high.x, low.y),
	])
	var best : float = INF
	var chosen : Rect2 = Rect2()
	for spot in spots:
		var area : Rect2 = Rect2(spot.clamp(low, high).round(), extent)
		var cost : float = area.intersection(icon).get_area() * 4.0 + area.intersection(boat).get_area() * 2.0 + area.get_center().distance_to(icon.get_center()) * 0.05
		for dot in dots:
			if area.has_point(dot):
				cost += 3.0
		if cost < best:
			best = cost
			chosen = area
	return chosen

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ui.frameColor)

func draw_chart() -> void:
	var origin : Vector2 = chart_origin()
	draw_route(origin)
	var order : Array[Location] = atlas.locations.duplicate()
	order.sort_custom(func(a : Location, b : Location) -> bool: return a.mapPosition.y < b.mapPosition.y)
	for location in order:
		draw_place(location, origin)
	draw_friends(origin)
	draw_boat(origin + boat_position())

# A dotted line marching from the boat to where it's headed, or would go,
# ending in a little mark where it will stop.
func draw_route(origin : Vector2) -> void:
	var path : PackedVector2Array
	var sailed : float = 0.0
	if not trip.is_empty():
		path = trip.path
		sailed = cruise(tripDone) * trip.length
	else:
		var target : Location = hovered if hovered else selected
		if not target or target == atlas.current or not atlas.is_unlocked(target):
			return
		path = route(target)
	var length : float = path_length(path)
	if length - sailed < 3.0:
		return
	# Dashes with a dark edge so the way reads on any water, marching toward
	# where the boat is headed.
	var shadow : Color = Color(ui.frameColor, 0.75)
	var dash : float = 3.0
	var gap : float = 2.0
	var at : float = sailed + 6.0 - fmod(time * 6.0, dash + gap)
	var pixels : Array[Vector2] = []
	while at < length - 4.0:
		var run : float = 0.0
		while run < dash and at + run < length - 4.0:
			if at + run > sailed + 5.0:
				pixels.append((origin + along(path, at + run)[0]).floor())
			run += 1.0
		at += dash + gap
	for pixel in pixels:
		chart.draw_rect(Rect2(pixel - Vector2.ONE * 0.5, Vector2(2.0, 2.0)), shadow)
	for pixel in pixels:
		chart.draw_rect(Rect2(pixel, Vector2.ONE), routeColor)
	# A ring where it ends, beating gently.
	var end : Vector2 = (origin + path[path.size() - 1]).floor() + Vector2(0.5, 0.5)
	var beat : float = 2.5 + sin(time * 4.0) * 0.6
	chart.draw_arc(end, beat + 0.6, 0.0, TAU, 16, shadow, 1.4)
	chart.draw_arc(end, beat, 0.0, TAU, 16, routeColor, 0.8)

# The other players' boats, pale, with their names: waiting at their place,
# or along their way when they're sailing.
func draw_friends(origin : Vector2) -> void:
	var session : NetSession = NetSession.find(get_tree())
	if not session:
		return
	var font : Font = ui.font
	for id in session.states:
		var state : Dictionary = session.states[id]
		var at : Vector2
		var trip_of : Variant = state.get("trip")
		if trip_of is Array and (trip_of as Array).size() == 3:
			var from : Location = load_location(trip_of[0])
			var to : Location = load_location(trip_of[1])
			if not from or not to:
				continue
			at = berth(from, to.mapPosition).lerp(berth(to, from.mapPosition), cruise(trip_of[2]))
		else:
			var here : Location = load_location(state.get("loc", ""))
			if not here:
				continue
			# Beside the place, on the other side from where this player waits.
			at = berth(here, here.mapPosition + (here.mapPosition - rest_toward() if here == atlas.current else Vector2(-20.0, 6.0)))
		at = (origin + at).round()
		var bob : float = sin(time * 2.2 + id) * 0.5
		chart.draw_set_transform(at + Vector2(0.0, bob), 0.0, Vector2(-1.0, 1.0))
		if playerIcon:
			chart.draw_texture(playerIcon, Vector2(-playerIcon.get_width() * 0.5 - 1.0, -playerIcon.get_height()), RemotePlayer.GUEST_TINT)
		if boatIcon:
			chart.draw_texture(boatIcon, -Vector2(boatIcon.get_width() * 0.5, 2.0), Color(0.85, 0.85, 0.9))
		chart.draw_set_transform(Vector2.ZERO)
		var tag : Vector2 = at + Vector2(-30.0, -9.0)
		chart.draw_string_outline(font, tag, Net.name_of(id), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 3, 1, ui.frameColor)
		chart.draw_string(font, tag, Net.name_of(id), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 3, RemotePlayer.NAME_COLOR)

func load_location(path : String) -> Location:
	return load(path) as Location if not path.is_empty() and ResourceLoader.exists(path) else null

func draw_place(location : Location, origin : Vector2) -> void:
	var center : Vector2 = (origin + location.mapPosition).round()
	var extent : Vector2 = icon_size(location)
	var open : bool = atlas.is_unlocked(location)
	var outline : Color = ui.selectedColor if location == selected else (ui.hoverColor if location == hovered else Color(0.0, 0.0, 0.0, 0.0))
	if location.mapIcon:
		ui.draw_icon(chart, location.mapIcon, center, Color.WHITE if open else lockedTint, outline, 1.0)
	else:
		var area : Rect2 = Rect2(center - extent * 0.5, extent)
		chart.draw_rect(area.grow(1.0), outline if outline.a > 0.0 else ui.frameColor)
		chart.draw_rect(area, seaColor.lightened(0.3) if open else lockedTint)
	if not open and lockIcon:
		chart.draw_texture(lockIcon, (center + Vector2(extent.x * 0.5 - lockIcon.get_width() + 1.0, -extent.y * 0.5 - 2.0)).round())
	var font : Font = ui.font
	var color : Color = ui.selectedColor if location == atlas.current else (ui.textColor if open else ui.dimColor)
	var baseline : Vector2 = Vector2(center.x - 40.0, center.y + extent.y * 0.5 + 2.0 + font.get_ascent(ui.statSize)).round()
	chart.draw_string_outline(font, baseline, location.displayName, HORIZONTAL_ALIGNMENT_CENTER, 80.0, ui.statSize, 1, ui.frameColor)
	chart.draw_string(font, baseline, location.displayName, HORIZONTAL_ALIGNMENT_CENTER, 80.0, ui.statSize, color)

# The player sits in the boat: drawn first, the hull covers their legs. The
# boat rocks gently and leaves a trail of foam while sailing.
func draw_boat(at : Vector2) -> void:
	var sailing : bool = not trip.is_empty() and tripDone < 1.0 and heading != Vector2.ZERO
	if sailing:
		var direction : Vector2 = heading
		for i in 5:
			var back : float = 5.0 + i * 3.0 + fmod(time * sailSpeed * 0.25, 3.0)
			var spread : float = i * 0.6
			var fade : Color = Color(ui.textColor, 0.7 - i * 0.13)
			var behind : Vector2 = at - direction * back + Vector2(0.0, 1.0)
			chart.draw_rect(Rect2(behind + direction.orthogonal() * spread, Vector2.ONE), fade)
			chart.draw_rect(Rect2(behind - direction.orthogonal() * spread, Vector2.ONE), fade)
	else:
		var ripple : float = floorf(fmod(time * 1.5, 2.0))
		chart.draw_rect(Rect2(at + Vector2(-8.0 - ripple, 2.0), Vector2(2.0, 1.0)), Color(ui.textColor, 0.5))
		chart.draw_rect(Rect2(at + Vector2(6.0 + ripple, 2.0), Vector2(2.0, 1.0)), Color(ui.textColor, 0.5))
	var bob : float = sin(time * (5.0 if sailing else 2.2)) * 0.5
	chart.draw_set_transform(at + Vector2(0.0, bob), sin(time * 1.7) * 0.05 * (2.0 if sailing else 1.0), Vector2(boatFacing, 1.0))
	if playerIcon:
		chart.draw_texture(playerIcon, Vector2(-playerIcon.get_width() * 0.5 - 1.0, -playerIcon.get_height() - 0.0))
	if boatIcon:
		chart.draw_texture(boatIcon, -Vector2(boatIcon.get_width() * 0.5, 2.0))
	chart.draw_set_transform(Vector2.ZERO)
	# A small gold marker over this player's own boat.
	var pin : Vector2 = (at + Vector2(0.0, -11.0 + sin(time * 3.0) * 0.8)).round()
	chart.draw_colored_polygon(PackedVector2Array([pin + Vector2(-2.5, -2.0), pin + Vector2(2.5, -2.0), pin + Vector2(0.0, 1.0)]), ui.frameColor)
	chart.draw_colored_polygon(PackedVector2Array([pin + Vector2(-1.5, -1.5), pin + Vector2(1.5, -1.5), pin + Vector2(0.0, 0.3)]), ui.selectedColor)

func draw_overlay() -> void:
	draw_bar()
	draw_arrows()
	draw_card()
	draw_tip()

func draw_bar() -> void:
	var font : Font = ui.font
	if hubbed:
		draw_plate(font)
		return
	overlay.draw_rect(barRect, ui.panelColor)
	overlay.draw_rect(Rect2(0.0, barRect.end.y - 1.0, barRect.size.x, 1.0), ui.frameColor)
	var baseline : float = roundf((barHeight + font.get_ascent(ui.titleSize)) * 0.5) - 1.0
	overlay.draw_string(font, Vector2(edge + 1.0, baseline), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, ui.textColor)
	var pen : float = closeRect.position.x - 3.0
	if trip.is_empty():
		draw_button(closeRect, zone == Zone.CLOSE)
		var cross : Rect2 = closeRect.grow(-2.5)
		overlay.draw_line(cross.position, cross.end, ui.textColor, 1.0)
		overlay.draw_line(Vector2(cross.end.x, cross.position.y), Vector2(cross.position.x, cross.end.y), ui.textColor, 1.0)
	pen = bar_item(pen, baseline, clock_text(cycle.time), null, ui.textColor)
	pen = bar_item(pen - 3.0, baseline, "%d" % ceili(player.energy.value), energyIcon, ui.textColor)
	bar_item(pen - 3.0, baseline, "%d" % player.wallet.coins, coinIcon, ui.selectedColor)

# The time, energy and coins on a little plate in the chart's bottom left.
func draw_plate(font : Font) -> void:
	var items : Array = [[clock_text(cycle.time), null, ui.textColor], ["%d" % ceili(player.energy.value), energyIcon, ui.textColor], [UiKit.coins_text(player.wallet.coins), coinIcon, ui.selectedColor]]
	var width : float = 4.0
	for item in items:
		width += UiKit.text_width(font, item[0], ui.statSize) + (item[1].get_width() + 1.0 if item[1] else 0.0) + 5.0
	var plate : Rect2 = Rect2(viewRect.position.x + 2.0, viewRect.end.y - 12.0, width, 9.0)
	UiKit.box(overlay, paper.well, plate.grow(1.0))
	overlay.draw_rect(plate, Color(0.05, 0.1, 0.18, 0.85))
	var x : float = plate.position.x + 3.0
	var baseline : float = UiKit.baseline(font, plate, ui.statSize)
	for item in items:
		var icon : Texture2D = item[1]
		if icon:
			overlay.draw_texture(icon, Vector2(x, floorf(plate.get_center().y - icon.get_height() * 0.5)))
			x += icon.get_width() + 1.0
		overlay.draw_string(font, Vector2(x, baseline), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, item[2])
		x += UiKit.text_width(font, item[0], ui.statSize) + 5.0

# Draws right-aligned text with its icon in front, returns where it starts.
func bar_item(right : float, baseline : float, text : String, icon : Texture2D, color : Color) -> float:
	var width : float = ui.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize).x
	var x : float = right - width
	overlay.draw_string(ui.font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, color)
	if icon:
		x -= icon.get_width() + 1.0
		overlay.draw_texture(icon, Vector2(x, floorf((barHeight - 1.0 - icon.get_height()) * 0.5)))
	return x

func draw_button(area : Rect2, lit : bool, color : Color = ui.frameColor) -> void:
	overlay.draw_rect(area, ui.hoverColor if lit else color)
	overlay.draw_rect(area.grow(-1.0), ui.slotColor)

func draw_arrows() -> void:
	var most : float = max_scroll()
	if most <= 0.0:
		return
	for right in [false, true]:
		var area : Rect2 = rightRect if right else leftRect
		if (scrollGoal >= most) if right else (scrollGoal <= 0.0):
			continue
		draw_button(area, zone == (Zone.RIGHT if right else Zone.LEFT))
		var direction : float = 1.0 if right else -1.0
		var tip : Vector2 = area.get_center() + Vector2(direction * 1.5, 0.0)
		var back : float = tip.x - direction * 3.0
		overlay.draw_colored_polygon(PackedVector2Array([tip, Vector2(back, tip.y - 2.0), Vector2(back, tip.y + 2.0)]), ui.textColor)
	var track : Rect2 = Rect2(viewRect.position.x + 8.0, viewRect.end.y - 2.0, viewRect.size.x - 16.0, 1.0)
	var length : float = maxf(track.size.x * viewRect.size.x / (viewRect.size.x + most), 6.0)
	overlay.draw_rect(track, Color(ui.frameColor, 0.6))
	overlay.draw_rect(Rect2(track.position.x + (track.size.x - length) * scroll / most, track.position.y, length, 1.0), ui.hoverColor)

func draw_card() -> void:
	if not selected or card.is_empty():
		return
	var font : Font = ui.font
	overlay.draw_rect(Rect2(cardRect.position + Vector2(2.0, 2.0), cardRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(overlay, paper.frame, cardRect)
	var inner : float = cardRect.size.x - cardPadding * 2.0
	var pen : Vector2 = cardRect.position + Vector2(cardPadding, cardPadding)
	overlay.draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.titleSize)), selected.displayName, HORIZONTAL_ALIGNMENT_LEFT, inner, ui.titleSize, paper.title)
	overlay.draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), selected.kind_name(), HORIZONTAL_ALIGNMENT_RIGHT, inner, ui.statSize, paper.dim)
	pen.y += ui.titleSize + 2.0
	for line in description_lines(selected):
		overlay.draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, paper.dim)
		pen.y += ui.statSize + 1.0
	for row in card.rows:
		var baseline : Vector2 = pen + Vector2(0.0, font.get_ascent(ui.statSize))
		overlay.draw_string(font, baseline, row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, paper.dim)
		overlay.draw_string(font, baseline, row[1], HORIZONTAL_ALIGNMENT_RIGHT, inner, ui.statSize, paper.readable(row[2]))
		pen.y += ui.statSize + 1.0
	var enabled : bool = card.enabled
	UiKit.button(overlay, font, paper, actionRect, card.action, ui.statSize, enabled, zone == Zone.ACTION, pressedAt != null and zone == Zone.ACTION)
	if action2Rect.has_area():
		UiKit.button(overlay, font, paper, action2Rect, card.action2, ui.statSize, card.enabled2, zone == Zone.ACTION2, pressedAt != null and zone == Zone.ACTION2)
	if selected.coinCost > 0 and not atlas.is_unlocked(selected) and coinIcon:
		overlay.draw_texture(coinIcon, Vector2(actionRect.position.x - coinIcon.get_width() - 2.0, actionRect.get_center().y - coinIcon.get_height() * 0.5).round())

func draw_tip() -> void:
	var title_text : String = ""
	var color : Color = ui.textColor
	var lines : PackedStringArray = PackedStringArray()
	if zone == Zone.CLOSE:
		title_text = "Close"
		lines = PackedStringArray([mapKeyText + " or Esc", ""])
	elif zone == Zone.PLACE and hovered and hovered != selected:
		title_text = hovered.displayName
		if hovered == atlas.current:
			lines = PackedStringArray(["You are here", ""])
		elif atlas.is_unlocked(hovered):
			var energy : float = atlas.energy_cost(hovered)
			lines = PackedStringArray(["Energy", "Free" if energy <= 0.0 else "%d" % energy, "Time", hours_text(atlas.travel_hours(hovered))])
		else:
			color = ui.dimColor
			lines = PackedStringArray(["Locked", ""])
	if title_text.is_empty():
		return
	ui.paint_tip(overlay, mouse, title_text, color, lines, ui.tip_size(title_text, lines))
