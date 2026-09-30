extends CharacterBody2D
class_name Player

const GROUP : StringName = &"players"

# Skill XP was earned, and a skill went up a level (see Skills).
@warning_ignore("unused_signal")
signal xp_gained(skill : StringName, amount : float)
@warning_ignore("unused_signal")
signal skill_up(skill : StringName, level : int)
# A fish was landed (tournaments listen).
@warning_ignore("unused_signal")
signal fish_caught(fish : Fish, biome : Biome)
# Around the feet: all of these have to be on land (or deck) to stand there.
const FEET : PackedVector2Array = [Vector2(-3.0, 3.0), Vector2(3.0, 3.0), Vector2(0.0, 0.5), Vector2(0.0, 5.5)]

#------------------------#
@onready var animationPlayer : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = %Sprite
@onready var body : Node2D = $Body
@onready var shadow : Sprite2D = $Shadow
@onready var center : Node2D = $Center
@onready var hand : Sprite2D = %Hand
@onready var itemHolder : Node2D = %ItemHolder
@onready var handStates : StateMachine = $HandStateMachine
#----------Movement Variables-----------#
@export var speed : float = 50.0
@export var acceleration : float = 100.0
@export var deceleration : float = 80.0

#----------Hand Variables-----------#
@export var boat : Boat
@export var inventory : Inventory
@export var tacklebox : Tacklebox
@export var journal : Journal
@export var energy : Energy
@export var wallet : Wallet
# The sea chart: where the boat is and which places are unlocked.
@export var atlas : Atlas
# Secrets found, aquarium donations, the farm and so on.
@export var progress : Progress
# Energy used up by every cast.
@export var castEnergy : float = 2.0
@export var minigameScreen : MinigameScreen
# How big held items other than rods are drawn. Meant for the settings screen.
@export_range(0.25, 2.0, 0.05) var heldItemScale : float = 0.75:
	set(value):
		heldItemScale = value
		if heldItem:
			heldItem.set_icon_scale(value)
@export var heldIconScene : PackedScene
@export var handRadius : float = 8.0
@export var footOffset : float = 7.0
@export var aimSpeed : float = 25.0
@export var flipSpeed : float = 12.0
@export var handStiffness : float = 280.0
@export_range(0.0, 1.0) var handDamping : float = 0.55
@export var itemStiffness : float = 340.0
@export_range(0.0, 1.0) var itemDamping : float = 0.45
@export var walkBob : float = 0.45
# Where the top of the head is, for items held up over it.
@export var headTop : float = -8.0
@export var overheadGap : float = -0.5
@export var overheadSway : float = 0.04
@export var idleSway : float = 0.025

var center_follow_speed : float = 15.0
var center_rest_position : Vector2
var last_global_position : Vector2

var heldItem : HeldItem
var offHand : Sprite2D
var heldSlot : int = -1
var rooted : bool = false
var asleep : bool = false
# Looking at the sea chart or sailing across it: no walking around.
var charting : bool = false
# Held still for a moment, like while the screen fades to the next room or a
# shop counter is open.
var frozen : bool = false
# The closest thing in reach that F would use.
var interactTarget : Interactable
var promptKey : Object
var promptText : String = ""
# The farm tile under the cursor, and what clicking it would do.
var farmTarget : FarmPlot
var farmTile : int = -1
var farmText : String = ""
var aimTarget : Variant = null
var facing : float = 1.0
var facingBlend : float = 1.0
var aim : float = 0.0
var poseAngle : float = 0.0
var poseOffset : Vector2 = Vector2.ZERO
var itemScale : float = 1.0
var handScale : Vector2 = Vector2.ONE
var handOffset : Vector2 = Vector2.ZERO
var handVelocity : Vector2 = Vector2.ZERO
var itemAngle : float = -PI / 2.0
var itemVelocity : float = 0.0
var poseTween : Tween
var lean : float = 0.0
var time : float = 0.0
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	inventory.setup()
	inventory.gained.connect(func(item : Item, amount : int) -> void: Collections.add(self, item, amount))
	if progress:
		progress.setup()
	if tacklebox:
		tacklebox.setup()
		tacklebox.gained.connect(func(part : Tackle, amount : int) -> void: Collections.add(self, part, amount))
	if journal:
		journal.setup()
	center_rest_position = center.position
	offHand = hand.duplicate()
	offHand.visible = false
	center.add_child(offHand)
	last_global_position = global_position
	if boat:
		shadow.material.set_shader_parameter("occluders", boat.occluders.slice(0, 3).map(func(occluder : Sprite2D) -> Texture2D: return occluder.texture))
	(%Prompt as Callout).warm_up("[]")
	warm_up()

func warm_up() -> void:
	var items : Array[HeldItem] = []
	var scenes : Array[PackedScene] = [heldIconScene]
	for slot in inventory.items:
		if slot and slot.heldScene and not scenes.has(slot.heldScene):
			scenes.append(slot.heldScene)
	for scene in scenes:
		if scene:
			var item : HeldItem = scene.instantiate()
			item.holder = self
			item.modulate.a = 0.01
			itemHolder.add_child(item)
			items.append(item)
	for i in 4:
		await get_tree().process_frame
	for item in items:
		item.queue_free()

func _physics_process(delta: float) -> void:
	time += delta
	move_center(delta)
	update_hand(delta)
	body.rotation = -lean * facingBlend

static func find(tree : SceneTree) -> Player:
	return tree.get_first_node_in_group(GROUP) as Player

func _process(delta : float) -> void:
	if progress:
		progress.playtime += delta
	update_shadow()
	update_interaction()

func update_shadow() -> void:
	var points : PackedVector2Array = PackedVector2Array()
	if boat and boat.deckFloor and not Island.current(get_tree()):
		points = Boat.texel_transform(shadow) * boat.deckFloor.global_transform * boat.deckFloor.polygon
	elif shadow.texture:
		var size : Vector2 = shadow.texture.get_size()
		points = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
	var count : int = mini(points.size(), 16)
	points.resize(16)
	var axes : PackedVector4Array = PackedVector4Array()
	var origins : PackedVector2Array = PackedVector2Array()
	axes.resize(3)
	origins.resize(3)
	var occluderCount : int = mini(boat.occluders.size(), 3) if boat else 0
	for i in occluderCount:
		var toTexel : Transform2D = Boat.texel_transform(boat.occluders[i]) * Boat.texel_transform(shadow).affine_inverse()
		axes[i] = Vector4(toTexel.x.x, toTexel.x.y, toTexel.y.x, toTexel.y.y)
		origins[i] = toTexel.origin
	var rid : RID = shadow.material.get_rid()
	RenderingServer.material_set_param(rid, "occluder_axes", axes)
	RenderingServer.material_set_param(rid, "occluder_origin", origins)
	RenderingServer.material_set_param(rid, "occluder_count", occluderCount)
	RenderingServer.material_set_param(rid, "floor_points", points)
	RenderingServer.material_set_param(rid, "floor_count", count)

# Whether the player could stand here. On islands that means on land, out at
# sea the boat's walls are all there is.
func can_stand(at : Vector2) -> bool:
	var island : Island = Island.current(get_tree())
	if not island or not island.world:
		return true
	for foot in FEET:
		if not island.walkable(at + foot):
			return false
	return true

# Picks the closest thing in reach to use with F, and the farm tile under the
# cursor, and shows the prompt for whichever applies (the cursor wins).
func update_interaction() -> void:
	var free : bool = handStates.currentState is PlayerHandIdleState and not asleep and not charting and not frozen
	update_farm_hover(free)
	var target : Interactable = null
	if free:
		var closest : float = INF
		for node : Interactable in get_tree().get_nodes_in_group(Interactable.GROUP):
			if not node.listed or not node.is_visible_in_tree() or not node.available(self):
				continue
			var distance : float = node.distance_to(global_position)
			if distance <= node.reach and distance < closest:
				closest = distance
				target = node
	interactTarget = target
	var key : Object = null
	var text : String = ""
	var at : Vector2 = Vector2.ZERO
	var color : Color = Color.WHITE
	if farmTarget and not farmText.is_empty():
		key = farmTarget
		text = farmText
		at = farmTarget.tile_center(farmTile) + Vector2(0.0, -7.0)
		color = farmTarget.hoverColor if farmTarget.in_reach(self, farmTile) else farmTarget.farColor
	elif target:
		key = target
		text = "[F] " + target.prompt_text(self)
		at = target.prompt_point(self)
		color = target.prompt_color(self)
	var prompt : Callout = %Prompt
	if key == promptKey and text == promptText:
		if key:
			prompt.anchor = at
		return
	promptKey = key
	promptText = text
	if key:
		prompt.pop(at, text, Color(color, 1.0))
	else:
		prompt.dismiss()

func update_farm_hover(free : bool) -> void:
	var plot : FarmPlot = null
	var tile : int = -1
	if free:
		var mouse : Vector2 = aimTarget if aimTarget != null else get_global_mouse_position()
		for node : FarmPlot in get_tree().get_nodes_in_group(FarmPlot.GROUP):
			var index : int = node.tile_at(mouse) if node.is_visible_in_tree() else -1
			if index >= 0:
				plot = node
				tile = index
				break
	if is_instance_valid(farmTarget) and farmTarget != plot:
		farmTarget.set_hover(-1, false)
	farmTarget = plot
	farmTile = tile
	farmText = plot.hover_text(self, tile) if plot else ""
	if plot:
		plot.set_hover(tile, plot.in_reach(self, tile))

# A click on the farm tile under the cursor. Returns whether it was used.
func click_farm() -> bool:
	return is_instance_valid(farmTarget) and farmTile >= 0 and farmTarget.click(self, farmTile)
# One of the active pet's buff multipliers, 1 without a pet.
func pet_stat(property : StringName) -> float:
	var pet : PetData = progress.activePet if progress else null
	return pet.stat(property, progress.pet_level(pet)) if pet else 1.0

# A multiplier stat with everything helping out: pet, food, weather, skills,
# charms, boat and pearls (see Stats). 1 changes nothing.
func boost(property : StringName) -> float:
	return Stats.of(self, property)

func stat(property : StringName) -> float:
	return Stats.of(self, property)

# Boat cabins, pearls and charms can raise the maximum energy.
func refresh_energy_max() -> void:
	if energy:
		energy.maximum = 100.0 + stat(&"energyMax")
		energy.value = minf(energy.value, energy.maximum)
		energy.emit_changed()

# A short line over the head, like "+20 energy".
func say(text : String, color : Color) -> void:
	(%CatchText as Callout).pop(center.global_position + Vector2(0.0, -12.0), text, color, 1.2)

func move_center(delta: float):
	center.position -= global_position - last_global_position
	last_global_position = global_position

	center.position = center.position.lerp(center_rest_position,
	1.0 - exp(-center_follow_speed * delta))

func update_hand(delta : float) -> void:
	var direction : Vector2 = (aimTarget if aimTarget != null else get_global_mouse_position()) - center.global_position
	if absf(direction.x) > 1.0:
		facing = signf(direction.x)
	aim = lerpf(aim, clampf(atan2(direction.y, direction.x * facing), -PI / 2.0, PI / 2.0), 1.0 - exp(-aimSpeed * delta))
	facingBlend = lerpf(facingBlend, facing, 1.0 - exp(-flipSpeed * delta))
	handVelocity += (handStiffness * (poseOffset - handOffset) - 2.0 * handDamping * sqrt(handStiffness) * handVelocity) * delta
	handOffset += handVelocity * delta
	var orbit : float = aim * (heldItem.handAimWeight if heldItem else 1.0)
	var bob : float = sin(time * TAU / 0.3) * walkBob * clampf(velocity.length() / speed, 0.0, 1.0)
	var local : Vector2 = Vector2.from_angle(orbit) * handRadius + handOffset + Vector2(0.0, 1.0 + bob)
	hand.position = Vector2(local.x * facingBlend, local.y)
	hand.rotation = atan2(sin(orbit), cos(orbit) * facingBlend)
	hand.scale = handScale
	itemHolder.position = hand.position
	if boat:
		var bodyRect : Rect2 = Rect2(global_position - Vector2(5.0, 8.0), Vector2(10.0, 16.0)).expand(hand.global_position)
		boat.fade_occluders(is_behind_occluders() and boat.overlaps_occluders(bodyRect.grow(2.0 if boat.faded else 0.0)))
	offHand.visible = heldItem != null and heldItem.overhead
	if offHand.visible:
		hold_overhead(bob)
	elif heldItem:
		update_item(delta)

func update_item(delta : float) -> void:
	var goal : float = heldItem.rest_angle(aim) + poseAngle + sin(time * 1.7) * idleSway
	itemVelocity += (itemStiffness * (goal - itemAngle) - 2.0 * itemDamping * sqrt(itemStiffness) * itemVelocity) * delta
	itemAngle += itemVelocity * delta
	var size : float = maxf(itemScale, 0.001)
	itemHolder.rotation = atan2(sin(itemAngle), cos(itemAngle) * facingBlend)
	itemHolder.scale = Vector2(size, size if facingBlend >= 0.0 else -size)
	heldItem.appear = itemScale
	heldItem.angularVelocity = itemVelocity

# Both hands hold the item up over the head at its bottom corners, however
# wide it is, and it faces the way the body faces (walking), not the mouse.
func hold_overhead(bob : float) -> void:
	var size : float = maxf(itemScale, 0.001)
	var extent : Vector2 = heldItem.held_extent() * size
	var middle : Vector2 = Vector2(0.0, headTop - overheadGap - extent.y * 0.5 + bob) + handOffset * 0.5
	itemHolder.position = middle
	itemHolder.rotation = sin(time * 1.7) * overheadSway
	itemHolder.scale = Vector2(size * sprite.scale.x, size)
	var corner : Vector2 = Vector2(maxf(extent.x * 0.5 - 1.5, 2.0), extent.y * 0.5 - 1.0)
	hand.position = middle + corner.rotated(itemHolder.rotation)
	offHand.position = middle + Vector2(-corner.x, corner.y).rotated(itemHolder.rotation)
	hand.rotation = -PI * 0.5
	offHand.rotation = -PI * 0.5
	hand.scale = handScale
	offHand.scale = handScale
	heldItem.appear = itemScale
	heldItem.angularVelocity = 0.0

func snap_item() -> void:
	if heldItem:
		itemAngle = heldItem.rest_angle(aim) + poseAngle
		itemVelocity = 0.0

func equip(slot : int) -> void:
	if heldItem:
		heldItem.queue_free()
		heldItem = null
	heldSlot = slot if slot >= 0 and slot < inventory.hotbarSize else -1
	var item : Item = inventory.get_item(heldSlot)
	var scene : PackedScene = (item.heldScene if item.heldScene else heldIconScene) if item else null
	if scene:
		heldItem = scene.instantiate()
		heldItem.holder = self
		heldItem.item = item
		itemHolder.add_child(heldItem)
		snap_item()
		update_item(0.0)

# Ends whatever the hand was doing (a catch, a cast in the water) and puts a
# fresh copy of the held item back in it, like after falling asleep.
func wake_reset() -> void:
	if not handStates.currentState is PlayerHandIdleState:
		handStates.change_state(handStates.get_node("Idle"))
		equip(heldSlot)

func held_data() -> Item:
	return heldItem.item if heldItem else null

# Like pressing the slot's number key: only while the hand is free.
func pick_slot(slot : int) -> void:
	if asleep:
		return
	if handStates.currentState is PlayerHandIdleState:
		(handStates.currentState as PlayerHandIdleState).pick(slot)
	elif handStates.currentState is PlayerSwitchState:
		var switching : PlayerSwitchState = handStates.currentState
		switching.choose(-1 if slot == switching.target() else slot)

# The held slot stays put while the hand is busy with it.
func can_move_slot(slot : int) -> bool:
	return slot != heldSlot or handStates.currentState is PlayerHandIdleState

func slot_pressed(event : InputEvent) -> int:
	for i in inventory.hotbarSize:
		var action : String = "slot_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return i
	return -1

func is_behind_occluders() -> bool:
	return boat != null and not boat.occluders.is_empty() and global_position.y < boat.occluders[0].global_position.y

func get_ground_y() -> float:
	return global_position.y + footOffset + (boat.deckHeight if boat else 0.0)

func pose_to(angle : float, offset : Vector2, duration : float, transition : Tween.TransitionType = Tween.TRANS_SINE, easing : Tween.EaseType = Tween.EASE_IN_OUT, bodyLean : float = 0.0) -> Tween:
	stop_pose()
	poseTween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel().set_trans(transition).set_ease(easing)
	poseTween.tween_property(self, "poseAngle", angle, duration)
	poseTween.tween_property(self, "poseOffset", offset, duration)
	poseTween.tween_property(self, "lean", bodyLean, duration)
	return poseTween

func stop_pose() -> void:
	if poseTween:
		poseTween.kill()
