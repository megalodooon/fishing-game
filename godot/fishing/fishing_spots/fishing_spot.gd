@tool
extends Node2D
class_name FishingSpot

const GROUP : StringName = &"fishing_spots"
const PONDS : StringName = &"ponds"
const MAX_SCORE : int = 5

#------------------------#
@export var radius : float = 10.0
@export var lifetime : Vector2 = Vector2(20.0, 30.0)
@export var appearTime : float = 1.0
@export var disappearTime : float = 1.0
@export var resizeSpeed : float = 4.0
# Spawned spots take the fish of the ocean's biome instead.
@export var fish : Array[FishData] = []
# Where its fish come from, for the journal. Its fish replace the list above.
@export var biome : Biome
# Lets fish ask for this spot in particular.
@export var id : StringName = &""

@export_group("Pond")
# Stays for good instead of coming and going, like a well or a hidden pool.
# Casts that land on land around it still count, the bobber drops right in.
@export var permanent : bool = false
# Casts anywhere inside score this. 0 scores by distance from the middle.
@export_range(0, 5) var fixedScore : int = 0
# Whether a cast here pops up a rating word.
@export var rated : bool = true
# Bites take this many times longer here.
@export_range(0.1, 10.0, 0.1, "or_greater") var biteDelayScale : float = 1.0

@export_group("Look")
@export_range(0.1, 1.0) var squash : float = 0.5
@export var frameRate : float = 12.0
@export var ringSpeed : float = 4.0
@export var ringInterval : float = 1.0
@export var ringColor : Color = Color(0.9, 0.98, 1.0, 1.0)
@export_range(1, 8) var fadeSteps : int = 4

var sizeScale : float = 1.0
var lifetimeScale : float = 1.0
var size : float = 0.0
var presence : float = 0.0
var leaving : bool = false
var age : float = 0.0
var life : float = 0.0
var rings : PackedFloat32Array = PackedFloat32Array()
var ringTimer : float = 0.0
var frame : int = -1
var framePhase : float = 0.0
var random : RandomNumberGenerator = RandomNumberGenerator.new()
# The fish waiting here, picked ahead when the player can see it: a Sonar
# Array shows its shadow, a Deep Sonar shows it, and Deep Luck (fully grown)
# makes spots with a rare one shimmer. The next bite here is this fish.
var preview : FishData
var reveal : int = 0
var shimmer : bool = false
#------------------------#


func _ready() -> void:
	random.seed = randi()
	size = target_size()
	life = random.randf_range(lifetime.x, lifetime.y)
	framePhase = random.randf()
	ringTimer = random.randf() * ringInterval * 0.5
	if biome:
		fish = biome.fish
	if Engine.is_editor_hint():
		presence = 1.0
		return
	add_to_group(GROUP)
	scan.call_deferred()
	if permanent:
		add_to_group(PONDS)
		presence = 1.0

func _process(delta : float) -> void:
	age += delta
	size = lerpf(size, target_size(), 1.0 - exp(-resizeSpeed * delta))
	if not Engine.is_editor_hint():
		if not leaving and not permanent and age >= appearTime + life * lifetimeScale:
			disappear()
		presence = move_toward(presence, 0.0 if leaving else 1.0, delta / maxf(disappearTime if leaving else appearTime, 0.001))
		if leaving and presence <= 0.0 and rings.is_empty():
			queue_free()
			return
	update_rings(delta)
	var tick : int = floori(age * frameRate + framePhase)
	if tick != frame:
		frame = tick
		queue_redraw()

func target_size() -> float:
	return radius * (1.0 if Engine.is_editor_hint() else sizeScale)

# No new rings start after this, the ones already out finish spreading, and
# the spot frees itself once they are gone.
func disappear() -> void:
	leaving = true

func update_rings(delta : float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i] += ringSpeed * delta
		if rings[i] >= size:
			rings.remove_at(i)
	ringTimer -= delta
	if ringTimer <= 0.0:
		ringTimer += maxf(ringInterval, 0.05)
		if not leaving:
			rings.append(0.0)

func scan() -> void:
	var player : Player = Player.find(get_tree())
	if not player or not player.progress or fish.is_empty():
		return
	var sonar : int = BoatParts.tier(player.progress, BoatParts.SONAR)
	reveal = clampi(sonar - 1, 0, 2)
	var lucky : bool = TideTree.has(player, "deep_luck")
	preview = FishData.roll(fish, FishingContext.make(player, null, self)) if reveal > 0 or lucky else null
	shimmer = lucky and preview != null and preview.rarity != null and not preview.rarity.displayName in ["Common", "Uncommon"]

# The fish that bites here: the one picked ahead when it still can, then the
# next one is picked.
func take_fish(context : FishingContext) -> FishData:
	var picked : FishData = preview if preview and preview.can_bite(context) else FishData.roll(fish, context)
	if preview:
		scan()
	return picked

func _draw() -> void:
	if preview and preview.icon and presence > 0.0 and reveal > 0:
		var tint : Color = Color(1.0, 1.0, 1.0, 0.8 * presence) if reveal >= 2 else Color(0.02, 0.08, 0.16, 0.5 * presence)
		draw_texture(preview.icon, (-preview.icon.get_size() * 0.5).floor(), tint)
	if shimmer and presence > 0.0:
		for i in 3:
			var phase : float = age * 2.0 + i * 2.1
			if fmod(phase, 2.0) < 1.0:
				var at : Vector2 = Vector2(cos(i * 2.4 + floorf(phase * 0.5)), sin(i * 2.4 + floorf(phase * 0.5)) * squash) * size * 0.6
				draw_rect(Rect2(at.floor(), Vector2.ONE), Color(1.0, 0.86, 0.35, presence))
	for ring in rings:
		var shape : Vector2i = pixel_shape(ring)
		var strength : float = roundf(sin(clampf(ring / size, 0.0, 1.0) * PI) * fadeSteps) / fadeSteps
		if shape.y > 0 and strength > 0.0:
			var color : Color = Color(ringColor, ringColor.a * strength)
			for corner in PixelEllipse.outline(shape):
				draw_rect(Rect2(corner, Vector2.ONE), color)

# The pixel ellipse of a circle with this radius on the water. Rings grow a
# whole row at a time and take their width from it, so every ring keeps the
# same angled look (2 to 1 with the default squash).
func pixel_shape(reach : float) -> Vector2i:
	var height : int = roundi(reach * squash)
	return Vector2i(roundi(height / squash), height)

# How far a point is from the middle of the spot: 0 in the middle, 1 at the
# edge. The spot is a circle on the water seen at an angle, so up and down
# count as much as the squashed look suggests.
func center_distance(point : Vector2) -> float:
	var reach : float = size * presence
	if reach <= 0.0:
		return INF
	var offset : Vector2 = point - global_position
	return Vector2(offset.x, offset.y / squash).length() / reach

# 5 in the middle down to 1 at the edge, in equal steps. 0 outside the spot.
func score_at(point : Vector2) -> int:
	var distance : float = center_distance(point)
	if distance > 1.0:
		return 0
	if fixedScore > 0:
		return fixedScore
	return clampi(MAX_SCORE - floori(distance * MAX_SCORE), 1, MAX_SCORE)

# The permanent spot the point is in, if any.
static func pond_at(tree : SceneTree, point : Vector2) -> FishingSpot:
	for spot : FishingSpot in tree.get_nodes_in_group(PONDS):
		if spot.is_visible_in_tree() and spot.center_distance(point) <= 1.0:
			return spot
	return null

# The spot whose middle is closest to the point, if the point is inside one.
static func find_at(tree : SceneTree, point : Vector2) -> FishingSpot:
	var best : FishingSpot = null
	var closest : float = 1.0
	for spot : FishingSpot in tree.get_nodes_in_group(GROUP):
		var distance : float = spot.center_distance(point)
		if distance <= closest:
			best = spot
			closest = distance
	return best
