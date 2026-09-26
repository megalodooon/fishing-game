@tool
extends HeldItem
class_name FishingRod

enum Mode { HOLD, FLIGHT, WATER, REEL }

#------------------------#
@export var bobberScene : PackedScene:
	set(value):
		bobberScene = value
		if is_node_ready() and not Engine.is_editor_hint():
			spawn_bobber()
@export var lineColor : Color = Color(0.94, 0.97, 1.0, 0.85):
	set(value):
		lineColor = value
		if is_node_ready():
			line.default_color = value
@export var lineWidth : float = 0.45

@export_group("Rod")
@export var grip : Vector2 = Vector2(2.0, 13.0):
	set(value):
		grip = value
		layout()
@export var tip : Vector2 = Vector2(14.5, 0.5):
	set(value):
		tip = value
		layout()
@export var maxBend : float = 2.0
@export var swingBend : float = 0.07
@export var tensionBend : float = 0.03
@export var bendStiffness : float = 900.0
@export_range(0.0, 1.0) var bendDamping : float = 0.2

@export_group("Line")
@export_range(2, 32) var segments : int = 12
@export var hangLength : float = 7.0
@export var maxLineLength : float = 150.0
@export var slack : float = 1.015
@export var gravity : float = 330.0
@export var airDrag : float = 3.0
@export var bobberDrag : float = 4.5
@export var waterDrag : float = 5.0
@export var iterations : int = 6

@export_group("Cast")
@export var chargeTime : float = 2.2
@export var minCastDistance : float = 3.0
@export var maxCastDistance : float = 64.0
@export var landingMargin : float = 3.0
@export var airTime : Vector2 = Vector2(0.3, 0.55)
@export var slideSpeed : float = 25.0
@export var castGravity : float = 560.0
@export var maxFloatTime : float = 30.0
@export var offscreenMargin : float = 4.0
@export var reelSpeed : float = 120.0
@export var reelAcceleration : float = 480.0

@onready var sprite : Sprite2D = $Sprite
@onready var line : Line2D = $Line
@onready var target : Node2D = $Target

var mode : Mode = Mode.HOLD
var bobber : Bobber
var points : PackedVector3Array = PackedVector3Array()
var previous : PackedVector3Array = PackedVector3Array()
var floors : PackedFloat32Array = PackedFloat32Array()
var length : float = 0.0
var bend : float = 0.0
var bendVelocity : float = 0.0
var tension : float = 0.0
var reelVelocity : float = 0.0
var floatTime : float = 0.0
var resting : Vector2
var lastAnchor : Vector3
var flightStart : Vector3
var flightVelocity : Vector3
var flightTime : float = 0.0
var flightDuration : float = 0.0
var castBehind : bool = false
var targetPoint : Vector2
var targetGoal : Vector2
var targetAlpha : float = 0.0
var targetShown : bool = false
var time : float = 0.0
#------------------------#


func _ready() -> void:
	layout()
	if Engine.is_editor_hint():
		return
	line.default_color = lineColor
	target.draw.connect(draw_target)
	spawn_bobber()

func _physics_process(delta : float) -> void:
	if Engine.is_editor_hint() or not holder or not bobber:
		return
	time += delta
	if points.is_empty():
		reset_line()
	simulate(delta)
	update_bend(delta)
	update_visuals(delta)

func layout() -> void:
	if not is_node_ready() or not sprite.texture:
		return
	var size : Vector2 = sprite.texture.get_size()
	var pad : float = ceilf(maxBend) + 1.0
	sprite.region_enabled = true
	sprite.region_rect = Rect2(-Vector2(pad, pad), size + Vector2(pad, pad) * 2.0)
	sprite.rotation = -(tip - grip).angle()
	sprite.position = -(grip - size / 2.0).rotated(sprite.rotation)
	sprite.material.set_shader_parameter("grip", grip)
	sprite.material.set_shader_parameter("tip", tip)

func spawn_bobber() -> void:
	if bobber:
		bobber.queue_free()
		bobber = null
	if bobberScene:
		bobber = bobberScene.instantiate()
		bobber.z_as_relative = false
		bobber.visible = false
		add_child(bobber)

func reset_line() -> void:
	var anchor : Vector3 = tip_point()
	var count : int = segments + 1
	lastAnchor = anchor
	points.resize(count)
	previous.resize(count)
	floors.resize(count)
	length = hangLength * maxf(appear, 0.05)
	for i in count:
		points[i] = anchor - Vector3(0.0, 0.0, length * i / segments)
		previous[i] = points[i]
		floors[i] = 0.0

func tip_local() -> Vector2:
	return Vector2((tip - grip).length(), bend)

func tip_point() -> Vector3:
	var screen : Vector2 = to_global(tip_local())
	var ground : float = holder.get_ground_y()
	return Vector3(screen.x, ground, ground - screen.y)

func project(point : Vector3) -> Vector2:
	return Vector2(point.x, point.y - point.z)

func simulate(delta : float) -> void:
	var boat : Boat = holder.boat
	var flow : float = boat.speed if boat else 0.0
	var anchor : Vector3 = tip_point()
	var last : int = points.size() - 1
	var air : float = exp(-airDrag * delta)
	var heavy : float = exp(-bobberDrag * delta)
	var water : float = exp(-waterDrag * delta)
	var fall : Vector3 = Vector3(0.0, 0.0, gravity * delta * delta)
	var turn : float = clampf(absf(holder.facing - holder.facingBlend), 0.0, 1.0)
	if mode == Mode.HOLD and turn > 0.0:
		var carry : Vector3 = (anchor - lastAnchor) * turn
		for i in range(1, points.size()):
			points[i] += carry
			previous[i] += carry
	lastAnchor = anchor
	points[0] = anchor
	previous[0] = anchor
	for i in range(1, points.size()):
		var point : Vector3 = points[i]
		var base : float = bobber.floatHeight if i == last else 0.0
		var solid : bool = i == last and mode == Mode.REEL and boat != null and point.z < base + boat.deckHeight + 1.0 and boat.is_solid(Vector2(point.x, point.y))
		floors[i] = base + (boat.deckHeight if solid else 0.0)
		var velocity : Vector3 = (point - previous[i]) * (heavy if i == last else air)
		var shift : Vector3 = Vector3.ZERO
		if point.z <= floors[i] + 0.05:
			velocity = Vector3(velocity.x * water, velocity.y * water, maxf(velocity.z, 0.0))
			if not solid:
				shift.x = -flow * delta
		previous[i] = point + shift
		points[i] = point + velocity + shift - fall
	match mode:
		Mode.HOLD:
			length = hangLength * maxf(appear, 0.05)
		Mode.FLIGHT:
			fly(anchor, delta)
		Mode.WATER:
			floatTime += delta
			length = clampf(anchor.distance_to(points[last]) * slack, hangLength, maxLineLength)
		Mode.REEL:
			reel_in(anchor, delta)
	var pull : float = 0.0
	if mode != Mode.FLIGHT:
		var bob : Vector3 = points[last]
		if mode == Mode.WATER and boat:
			var free : Vector2 = collide(boat, Vector2(bob.x, bob.y), delta)
			if free != Vector2(bob.x, bob.y):
				bob = Vector3(free.x, free.y, bob.z)
				previous[last] = Vector3(free.x, free.y, previous[last].z)
		var offset : Vector3 = bob - anchor
		var distance : float = offset.length()
		if distance > length:
			pull = distance - length
			bob = anchor + offset / distance * length
		if bob.z < floors[last]:
			bob.z = floors[last] if floors[last] - bob.z < 1.0 else lerpf(bob.z, floors[last], 1.0 - exp(-18.0 * delta))
			var before : Vector3 = previous[last]
			before.z = bob.z
			previous[last] = before
		points[last] = bob
	resting = Vector2(points[last].x, points[last].y)
	tension = lerpf(tension, pull / delta, 1.0 - exp(-12.0 * delta))
	constrain_line(last)

func collide(boat : Boat, point : Vector2, delta : float) -> Vector2:
	if not boat.covers(point):
		return point
	var edge : float = resting.y
	for i in range(1, 96):
		if not boat.covers(point + Vector2(0.0, -i)):
			edge = point.y - i
			break
		if not boat.covers(point + Vector2(0.0, i)):
			edge = point.y + i
			break
	var slid : float = move_toward(resting.y, edge, slideSpeed * delta)
	for candidate : Vector2 in [Vector2(point.x, slid), Vector2(resting.x, slid)]:
		if not boat.covers(candidate):
			return candidate
	return resting

func constrain_line(last : int) -> void:
	var rest : float = length / segments
	for iteration in iterations:
		for i in last:
			var a : Vector3 = points[i]
			var b : Vector3 = points[i + 1]
			var offset : Vector3 = b - a
			var distance : float = offset.length()
			if distance < 0.0001:
				continue
			if i == 0:
				if last > 1:
					points[1] = b - offset * ((distance - rest) / distance)
			elif i + 1 == last:
				points[i] = a + offset * ((distance - rest) / distance)
			else:
				var correction : Vector3 = offset * ((distance - rest) / (distance * 2.0))
				points[i] = a + correction
				points[i + 1] = b - correction
		for i in range(1, last):
			var point : Vector3 = points[i]
			if point.z < floors[i]:
				point.z = floors[i]
				points[i] = point

func fly(anchor : Vector3, delta : float) -> void:
	var last : int = points.size() - 1
	flightTime = minf(flightTime + delta, flightDuration)
	points[last] = flight_point(flightTime)
	previous[last] = flight_point(flightTime - delta)
	length = maxf(length, anchor.distance_to(points[last]) * slack)
	if flightTime >= flightDuration:
		mode = Mode.WATER
		floatTime = 0.0
		previous[last] = points[last]
		length = anchor.distance_to(points[last]) * slack
		bobber.splash()

func flight_point(t : float) -> Vector3:
	return flightStart + flightVelocity * t - Vector3(0.0, 0.0, 0.5 * castGravity * t * t)

func reel_in(anchor : Vector3, delta : float) -> void:
	reelVelocity = move_toward(reelVelocity, reelSpeed, reelAcceleration * delta)
	length = minf(length, anchor.distance_to(points[points.size() - 1]) + 0.5) - reelVelocity * delta
	if length <= hangLength:
		length = hangLength
		mode = Mode.HOLD

func update_bend(delta : float) -> void:
	var toward : Vector2 = global_transform.basis_xform_inv(project(points[1]) - project(points[0]))
	var pull : float = toward.normalized().y * tension * tensionBend if toward.length_squared() > 0.0001 else 0.0
	var goal : float = clampf(pull - angularVelocity * swingBend, -maxBend, maxBend)
	bendVelocity += (bendStiffness * (goal - bend) - 2.0 * bendDamping * sqrt(bendStiffness) * bendVelocity) * delta
	bend = clampf(bend + bendVelocity * delta, -maxBend, maxBend)
	RenderingServer.material_set_param(sprite.material.get_rid(), "bend", bend)

func update_visuals(delta : float) -> void:
	var last : int = points.size() - 1
	var bob : Vector3 = points[last]
	var inWater : bool = mode != Mode.FLIGHT and bob.z <= floors[last] + 0.1 and floors[last] < bobber.floatHeight + 0.5
	bobber.place(Vector2(bob.x, bob.y), bob.z, inWater, holder.boat.speed if holder.boat else 0.0, appear)
	line.z_index = 0 if mode == Mode.HOLD else 1
	var inFront : bool = holder.boat != null and bob.y > holder.boat.global_position.y
	bobber.z_index = (line.z_index if inFront else -1) if inWater else line.z_index + 1
	var drawn : PackedVector2Array = PackedVector2Array()
	drawn.resize(points.size())
	for i in points.size():
		drawn[i] = project(points[i])
	drawn[0] = to_global(tip_local())
	drawn[last] = bobber.get_attach()
	line.global_transform = Transform2D.IDENTITY
	line.points = drawn
	line.width = lineWidth * appear
	update_occluders()
	targetPoint = targetPoint.lerp(targetGoal, 1.0 - exp(-25.0 * delta))
	var alpha : float = move_toward(targetAlpha, 1.0 if targetShown else 0.0, delta * 5.0)
	if alpha > 0.0 or targetAlpha > 0.0:
		target.queue_redraw()
	targetAlpha = alpha

func update_occluders() -> void:
	var boat : Boat = holder.boat
	if not boat:
		return
	boat.apply_occluders(bobber.sprite.material, mode != Mode.HOLD and not boat.faded)
	var shader : ShaderMaterial = line.material as ShaderMaterial
	if not shader.has_meta("occluders"):
		shader.set_meta("occluders", true)
		var data : Dictionary = boat.occluder_static().duplicate(true)
		var textures : Array = data["occluders"]
		var modes : PackedInt32Array = data["occluder_mode"]
		var first : PackedVector4Array = data["occluder_a"]
		textures[2] = sprite.texture
		modes[2] = 3
		first[2] = Vector4(grip.x, grip.y, tip.x, tip.y)
		data["occluders"] = textures
		data["occluder_mode"] = modes
		data["occluder_a"] = first
		for key in data:
			shader.set_shader_parameter(key, data[key])
	var toTexel : Transform2D = Boat.texel_transform(sprite)
	var axes : PackedVector4Array = boat.occluderAxes.duplicate()
	var origins : PackedVector2Array = boat.occluderOrigins.duplicate()
	axes[2] = Vector4(toTexel.x.x, toTexel.x.y, toTexel.y.x, toTexel.y.y)
	origins[2] = toTexel.origin
	var rid : RID = shader.get_rid()
	RenderingServer.material_set_param(rid, "occlude", mode != Mode.HOLD and castBehind)
	RenderingServer.material_set_param(rid, "occluder_strength", boat.occluders[0].modulate.a if not boat.occluders.is_empty() else 1.0)
	RenderingServer.material_set_param(rid, "occluder_axes", axes)
	RenderingServer.material_set_param(rid, "occluder_origin", origins)
	RenderingServer.material_set_param(rid, "rod_bend_amount", bend)

func draw_target() -> void:
	if targetAlpha <= 0.0:
		return
	var eased : float = targetAlpha * targetAlpha * (3.0 - 2.0 * targetAlpha)
	var pulse : float = sin(time * 7.0) * 0.5 + 0.5
	target.draw_set_transform(targetPoint, 0.0, Vector2(1.0, bobber.squash))
	target.draw_arc(Vector2.ZERO, 3.2 + pulse * 0.6 + (1.0 - eased) * 3.0, 0.0, TAU, 40, Color(lineColor, 0.6 * eased), 0.5, true)
	target.draw_circle(Vector2.ZERO, 0.8, Color(lineColor, 0.5 * eased), true, -1.0, true)

func charge_time() -> float:
	return maxf(chargeTime + (bobber.chargeTimeOffset if bobber else 0.0), 0.01)

func cast_range() -> float:
	return maxf(maxCastDistance + (bobber.rangeOffset if bobber else 0.0), minCastDistance)

func find_landing(origin : Vector2, toward : Vector2, power : float) -> Variant:
	var direction : Vector2 = origin.direction_to(toward) if origin.distance_squared_to(toward) > 0.01 else Vector2.RIGHT
	var boat : Boat = holder.boat if holder else null
	var edge : float = 0.0
	if boat and boat.covers(origin):
		while edge < 256.0 and boat.covers(origin + direction * edge):
			edge += 1.0
		edge += landingMargin
	var near : float = maxf(minCastDistance, edge)
	if near > cast_range():
		return null
	return origin + direction * lerpf(near, cast_range(), power)

func show_target(point : Vector2) -> void:
	if targetAlpha <= 0.0:
		targetPoint = point
	targetGoal = point
	targetShown = true

func hide_target() -> void:
	targetShown = false

func launch(point : Vector2) -> void:
	var start : Vector3 = points[points.size() - 1]
	var goal : Vector3 = Vector3(point.x, point.y, bobber.floatHeight)
	var reach : float = clampf(Vector2(goal.x - start.x, goal.y - start.y).length() / cast_range(), 0.0, 1.0)
	flightDuration = lerpf(airTime.x, airTime.y, sqrt(reach))
	flightVelocity = (goal - start) / flightDuration + Vector3(0.0, 0.0, 0.5 * castGravity * flightDuration)
	flightStart = start
	flightTime = 0.0
	mode = Mode.FLIGHT
	castBehind = holder.is_behind_occluders()

func reel() -> void:
	if mode == Mode.WATER or mode == Mode.FLIGHT:
		if bobber.inWater:
			bobber.splash(0.35)
		mode = Mode.REEL
		reelVelocity = 0.0

func should_return() -> bool:
	var screen : Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	return floatTime >= maxFloatTime or not screen.grow(offscreenMargin).has_point(bobber.get_attach())

func get_bobber_point() -> Vector2:
	var bob : Vector3 = points[points.size() - 1]
	return Vector2(bob.x, bob.y)
