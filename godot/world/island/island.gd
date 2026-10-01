extends Node2D
class_name Island

# A place to walk around: IslandRoom children laid out side by side, together
# one continuous island. The camera follows the player and stops at the
# island's edges (an island smaller than the screen sits in the middle). The
# player steps ashore at the arrival point while the boat stays out of
# sight, and sails off from anywhere with the sea chart. Rooms well out of
# view stop processing and their water stops rendering, so a big island
# costs little more than the bit on screen.
#
# Buildings with an inside (see Entrance) are Islands of their own, loaded
# over this one by the World while the player is in them.

const GROUP : StringName = &"islands"
# How far past the screen's edges rooms count as in view.
const VIEW_MARGIN : float = 48.0

#------------------------#
@export var fadeTime : float = 0.14
@export var fadeColor : Color = Color(0.02, 0.04, 0.08)
# Where the player steps ashore, from the island's origin: the end of the
# landing's pier.
@export var arrival : Vector2 = Vector2(30.0, 54.0)
# How quickly the camera catches up with the player.
@export var cameraSpeed : float = 9.0
# An inside of a building: no boat, no weather, the door leads back out.
@export var interior : bool = false

var rooms : Array[IslandRoom] = []
# The room the player is in.
var room : IslandRoom
var world : World
var fader : ColorRect
var switching : bool = false
var people : Array[Npc] = []
var grid : WalkGrid
var pendingGrid : WalkGrid
var gridTask : int = -1
var scheduleWait : float = 0.0
var viewWait : float = 0.0
var bounds : Rect2 = Rect2()
var cameraAt : Vector2 = Vector2.ZERO
# Rooms near enough to the screen to be awake.
var awake : Dictionary = {}
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	if interior:
		# Insides sit in the dark, whatever the screen shows past their walls.
		var dark : Polygon2D = Polygon2D.new()
		dark.polygon = PackedVector2Array([Vector2(-2000, -2000), Vector2(2192, -2000), Vector2(2192, 2108), Vector2(-2000, 2108)])
		dark.color = fadeColor
		dark.z_index = -30
		add_child(dark)
	for child in find_children("*", "IslandRoom", true, false):
		rooms.append(child)
		bounds = child.rect() if bounds.size == Vector2.ZERO else bounds.merge(child.rect())
		# The boat isn't sailing here, so the water around the island doesn't
		# scroll, and it's only drawn where the land doesn't cover it.
		for water in child.get_children():
			if water is Ocean:
				(water as Ocean).make_calm(child.land[0] if child.land.size() == 1 else null)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 19
	fader = ColorRect.new()
	fader.color = fadeColor
	fader.modulate.a = 0.0
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fader)
	add_child(layer)

static func current(tree : SceneTree) -> Island:
	return tree.get_first_node_in_group(GROUP) as Island

func enter(into : World, at : Variant = null) -> void:
	world = into
	world.boat.stow(true)
	world.player.global_position = at if at is Vector2 else global_position + arrival
	room = room_at(world.player.global_position)
	if not room and not rooms.is_empty():
		room = rooms[0]
	for each in rooms:
		each.visible = true
	people.clear()
	for person in find_children("*", "Npc", true, false):
		people.append(person)
	snap_camera()
	update_view()
	for person in people:
		(person as Npc).follow_schedule(true)
	start_grid()

# Starts working out the walking grid on a background thread.
func start_grid() -> void:
	if grid or gridTask >= 0:
		return
	pendingGrid = WalkGrid.prepare(self)
	gridTask = WorkerThreadPool.add_task(pendingGrid.build, false, "walk grid")

func _exit_tree() -> void:
	if gridTask >= 0:
		WorkerThreadPool.wait_for_task_completion(gridTask)
		gridTask = -1

func room_named(name_of_room : String) -> IslandRoom:
	for each in rooms:
		if each.name == name_of_room:
			return each
	return null

# The walking grid, or null while it's still being worked out (people then
# just turn up where they're going).
func walk_grid() -> WalkGrid:
	return grid

# The walking grid, waiting for it if needed (for things that can't do
# without, like burying a treasure trail).
func walk_grid_now() -> WalkGrid:
	if not grid:
		if gridTask < 0:
			start_grid()
		WorkerThreadPool.wait_for_task_completion(gridTask)
		gridTask = -1
		grid = pendingGrid
	return grid

# Whether a room is near enough to the screen that someone could see what
# happens in it.
func room_seen(which : IslandRoom) -> bool:
	return awake.get(which, false)

func _process(delta : float) -> void:
	if gridTask >= 0 and WorkerThreadPool.is_task_completed(gridTask):
		WorkerThreadPool.wait_for_task_completion(gridTask)
		gridTask = -1
		grid = pendingGrid
	if not world:
		return
	follow_camera(delta)
	viewWait -= delta
	if viewWait <= 0.0:
		viewWait = 0.2
		update_view()
	# Everyone on the island checks their schedule a few times a second:
	# people near the screen walk, the rest just turn up where they should be.
	scheduleWait -= delta
	if scheduleWait > 0.0:
		return
	scheduleWait = 0.25
	for person in people:
		if is_instance_valid(person) and not person.host:
			person.follow_schedule(false)

func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size

# Where the camera's top left corner wants to be: the player in the middle,
# but never past the island's edges.
func camera_goal() -> Vector2:
	var view : Vector2 = view_size()
	var goal : Vector2 = world.player.global_position - view * 0.5
	for axis in 2:
		if bounds.size[axis] <= view[axis]:
			goal[axis] = bounds.position[axis] + (bounds.size[axis] - view[axis]) * 0.5
		else:
			goal[axis] = clampf(goal[axis], bounds.position[axis], bounds.end[axis] - view[axis])
	return goal

func snap_camera() -> void:
	cameraAt = camera_goal()
	if world and world.camera:
		world.camera.position = cameraAt.round()
		world.camera.reset_smoothing()

func follow_camera(delta : float) -> void:
	if not world.camera:
		return
	cameraAt = cameraAt.lerp(camera_goal(), 1.0 - exp(-cameraSpeed * delta))
	world.camera.position = cameraAt.round()

# Wakes the rooms around the screen and puts the rest to sleep.
func update_view() -> void:
	var view : Rect2 = Rect2(cameraAt, view_size()).grow(VIEW_MARGIN)
	for each in rooms:
		var near : bool = each.rect().intersects(view)
		if awake.get(each, null) == near:
			continue
		awake[each] = near
		each.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
		for water in each.get_children():
			if water is Ocean:
				(water as Ocean).set_awake(near)
	var here : IslandRoom = room_at(world.player.global_position) if world else null
	if here:
		room = here

func leave() -> void:
	if world:
		if world.camera:
			world.camera.position = Vector2.ZERO
		world.boat.stow(false)
	world = null

func room_at(point : Vector2) -> IslandRoom:
	for each in rooms:
		if each.rect().has_point(point):
			return each
	return null

# A quick fade to dark and back, around a change of scene (like going through
# a door). Calls the callback while it's dark.
func fade_through(then : Callable) -> void:
	switching = true
	if world:
		world.player.frozen = true
	var out : Tween = create_tween()
	out.tween_property(fader, "modulate:a", 1.0, fadeTime).set_trans(Tween.TRANS_SINE)
	await out.finished
	then.call()
	# The other side fades in with its own fader; this one (on a canvas layer
	# that doesn't hide with the island) clears.
	fader.modulate.a = 0.0
	switching = false

func fade_in() -> void:
	fader.modulate.a = 1.0
	var back : Tween = create_tween()
	back.tween_property(fader, "modulate:a", 0.0, fadeTime * 1.5).set_trans(Tween.TRANS_SINE)
	await back.finished
	switching = false

func is_land(point : Vector2) -> bool:
	var at : IslandRoom = room_at(point)
	return at != null and at.is_land(point)

# Casts can't land on the ground, only in the sea or in a pond on land.
func blocks_cast(point : Vector2) -> bool:
	return is_land(point) and FishingSpot.pond_at(get_tree(), point) == null

func walkable(point : Vector2) -> bool:
	return is_land(point)
