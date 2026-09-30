extends Node2D
class_name Island

# A place to walk around: IslandRoom children laid out screen by screen. The
# player steps ashore at the arrival point while the boat stays out of sight,
# and sails off from anywhere on the island with the sea chart. Walking past
# a room's edge fades to the room on the other side.

const GROUP : StringName = &"islands"

#------------------------#
@export var fadeTime : float = 0.14
@export var fadeColor : Color = Color(0.02, 0.04, 0.08)
# Where the player steps ashore, from the island's origin: the end of the
# landing's pier.
@export var arrival : Vector2 = Vector2(30.0, 54.0)

var rooms : Array[IslandRoom] = []
var room : IslandRoom
var world : World
var fader : ColorRect
var switching : bool = false
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	for child in find_children("*", "IslandRoom", true, false):
		rooms.append(child)
		# The boat isn't sailing here, so the water around the island lies still,
		# and it's only drawn where the land doesn't cover it.
		for water in child.get_children():
			if water is Ocean:
				(water as Ocean).make_still(child.land[0] if child.land.size() == 1 else null)
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

func enter(into : World) -> void:
	world = into
	world.boat.stow(true)
	world.player.global_position = global_position + arrival
	var start : IslandRoom = room_at(world.player.global_position)
	show_room(start if start else rooms[0])

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

func _physics_process(_delta : float) -> void:
	if not world or switching or not room:
		return
	var at : Vector2 = world.player.global_position
	if room.rect().has_point(at):
		return
	var next : IslandRoom = room_at(at)
	if next:
		switch_to(next)

func switch_to(next : IslandRoom) -> void:
	switching = true
	world.player.frozen = true
	var out : Tween = create_tween()
	out.tween_property(fader, "modulate:a", 1.0, fadeTime).set_trans(Tween.TRANS_SINE)
	await out.finished
	show_room(next)
	world.player.frozen = false
	var back : Tween = create_tween()
	back.tween_property(fader, "modulate:a", 0.0, fadeTime).set_trans(Tween.TRANS_SINE)
	switching = false

func show_room(next : IslandRoom) -> void:
	room = next
	for each in rooms:
		each.visible = each == next
	# The shown room's water gets its passes rendered (and made the first time).
	for water in next.get_children():
		if water is Ocean:
			(water as Ocean).refresh_passes()
	if world.camera:
		world.camera.position = next.global_position
		world.camera.reset_smoothing()

func is_land(point : Vector2) -> bool:
	var at : IslandRoom = room_at(point)
	return at != null and at.is_land(point)

# Casts can't land on the ground, only in the sea or in a pond on land.
func blocks_cast(point : Vector2) -> bool:
	return is_land(point) and FishingSpot.pond_at(get_tree(), point) == null

func walkable(point : Vector2) -> bool:
	return is_land(point)
