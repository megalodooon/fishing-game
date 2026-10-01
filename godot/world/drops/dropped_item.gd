extends Node2D
class_name DroppedItem

# Something lying on the ground: from foraging, or thrown out of the bag (by
# dragging it out). It pops out in a little arc, bobs, and the player picks
# it up by walking over it (when there's room in the bag). After LIFE
# seconds it's gone, blinking for the last few, so the ground doesn't fill up.
# With a friend in the same place it shows in both games, and whoever picks
# it up gets it (see NetSession).

const GROUP : StringName = &"dropped_items"
const LIFE : float = 15.0
const REACH : float = 7.0
# Thrown things wait a moment before they can be picked up again.
const PICKUP_DELAY : float = 0.8
const ARC_TIME : float = 0.35

#------------------------#
var item : Item
var id : int = 0
var age : float = 0.0
var from : Vector2 = Vector2.ZERO
var to : Vector2 = Vector2.ZERO
var delay : float = 0.0
var player : Player
var taken : bool = false
#------------------------#


# Drops a stack at a point (out of from, for the arc). Shared with a friend
# in the same place unless it came from them.
static func spawn(tree : SceneTree, stack : Item, at : Vector2, out_of : Vector2 = Vector2.INF, share : bool = true, wait : float = 0.0, drop_id : int = 0, already : float = 0.0) -> DroppedItem:
	var world : World = World.find(tree)
	if not world or not stack:
		return null
	var drop : DroppedItem = DroppedItem.new()
	drop.item = stack
	drop.id = drop_id if drop_id != 0 else randi()
	drop.to = at
	drop.from = out_of if out_of != Vector2.INF else at
	drop.delay = wait
	drop.age = already
	drop.global_position = drop.from
	world.drops().add_child(drop)
	if share:
		var session : NetSession = NetSession.find(tree)
		if session:
			session.share_drop(drop)
	return drop

static func clear_all(tree : SceneTree) -> void:
	for drop in tree.get_nodes_in_group(GROUP):
		drop.queue_free()

static func by_id(tree : SceneTree, drop_id : int) -> DroppedItem:
	for drop in tree.get_nodes_in_group(GROUP):
		if (drop as DroppedItem).id == drop_id:
			return drop
	return null

func _ready() -> void:
	add_to_group(GROUP)
	player = Player.find(get_tree())
	z_index = 1

func _process(delta : float) -> void:
	age += delta
	delay = maxf(delay - delta, 0.0)
	var t : float = clampf(age / ARC_TIME, 0.0, 1.0)
	global_position = from.lerp(to, t) - Vector2(0.0, sin(t * PI) * 8.0)
	if age >= LIFE:
		queue_free()
		return
	if not taken and t >= 1.0 and delay <= 0.0 and player and not player.asleep and player.global_position.distance_to(to) < REACH:
		pick_up()
	queue_redraw()

func pick_up() -> void:
	if player.inventory.room_for(item) < item.amount and not item is Fish:
		return
	var left : int = player.inventory.give(item, item.amount) if not item is Fish else (0 if player.inventory.add(item) >= 0 else 1)
	if left >= item.amount:
		return
	var got : int = item.amount - left
	player.say("+%d %s" % [got, item.displayName] if got > 1 else "+ " + item.displayName, Color(0.8, 0.92, 0.6))
	if left > 0:
		item.amount = left
		return
	taken = true
	var session : NetSession = NetSession.find(get_tree())
	if session:
		session.drop_taken(id)
	queue_free()

func _draw() -> void:
	if not item or not item.icon:
		return
	# Blinks for the last few seconds.
	if age > LIFE - 3.0 and fmod(age, 0.3) < 0.12:
		return
	var bob : float = sin(age * 3.0) * 0.8 if age > ARC_TIME else 0.0
	var size : Vector2 = item.icon.get_size()
	var fit : float = minf(1.0, 9.0 / maxf(size.x, size.y))
	var drawn : Vector2 = size * fit
	draw_rect(Rect2(Vector2(-3.0, 0.5) + (to - global_position), Vector2(6.0, 1.0)), Color(0.0, 0.0, 0.0, 0.25))
	draw_texture_rect(item.icon, Rect2(Vector2(-drawn.x * 0.5, -drawn.y + bob).round(), drawn), false)
