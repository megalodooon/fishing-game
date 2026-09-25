extends CharacterBody2D
class_name Player

#------------------------#
@onready var animationPlayer : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = %Sprite
@onready var body : Node2D = $Body
@onready var shadow : Sprite2D = $Shadow
@onready var center : Node2D = $Center
@onready var hand : Sprite2D = %Hand
@onready var itemHolder : Node2D = %ItemHolder
#----------Movement Variables-----------#
@export var speed : float = 50.0
@export var acceleration : float = 100.0
@export var deceleration : float = 80.0

#----------Hand Variables-----------#
@export var boat : Boat
@export var hotbar : Array[PackedScene] = []
@export var handRadius : float = 8.0
@export var footOffset : float = 7.0
@export var aimSpeed : float = 25.0
@export var flipSpeed : float = 12.0
@export var handStiffness : float = 280.0
@export_range(0.0, 1.0) var handDamping : float = 0.55
@export var itemStiffness : float = 340.0
@export_range(0.0, 1.0) var itemDamping : float = 0.45
@export var walkBob : float = 0.45
@export var idleSway : float = 0.025

var center_follow_speed : float = 15.0
var center_rest_position : Vector2
var last_global_position : Vector2

var heldItem : HeldItem
var heldSlot : int = -1
var rooted : bool = false
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
	center_rest_position = center.position
	last_global_position = global_position
	if boat:
		shadow.material.set_shader_parameter("occluders", boat.occluders.slice(0, 3).map(func(occluder : Sprite2D) -> Texture2D: return occluder.texture))
	warm_up()

func warm_up() -> void:
	var items : Array[HeldItem] = []
	for scene in hotbar:
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

func _process(_delta : float) -> void:
	update_shadow()

func update_shadow() -> void:
	var points : PackedVector2Array = PackedVector2Array()
	if boat and boat.deckFloor:
		points = Boat.texel_transform(shadow) * boat.deckFloor.global_transform * boat.deckFloor.polygon
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
	if heldItem:
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

func snap_item() -> void:
	if heldItem:
		itemAngle = heldItem.rest_angle(aim) + poseAngle
		itemVelocity = 0.0

func equip(slot : int) -> void:
	if heldItem:
		heldItem.queue_free()
		heldItem = null
	heldSlot = slot if slot >= 0 and slot < hotbar.size() and hotbar[slot] else -1
	if heldSlot >= 0:
		heldItem = hotbar[heldSlot].instantiate()
		heldItem.holder = self
		itemHolder.add_child(heldItem)
		snap_item()
		update_item(0.0)

func slot_pressed(event : InputEvent) -> int:
	for i in hotbar.size():
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
