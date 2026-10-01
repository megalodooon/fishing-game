extends Node2D
class_name FishingSpotSpawner

# Out at sea, spots come in from the right as the boat sails. Docked at an
# island they're rarer: now and then one bubbles up somewhere in the water on
# screen and fades away again after a while.

#------------------------#
@export var boat : Boat
@export var player : Player
@export var spotScene : PackedScene
@export var maxSpots : int = 3
@export var spawnDelay : Vector2 = Vector2(2.0, 5.0)
@export var hullBand : Vector2 = Vector2(-2.0, 42.0)
@export var minSpacing : float = 24.0
@export var screenMargin : float = 12.0

@export_group("Docked")
@export var dockedMaxSpots : int = 1
@export var dockedDelay : Vector2 = Vector2(25.0, 60.0)
# How far from the hull docked spots keep, so they don't show up under the deck.
@export var hullClearance : float = 6.0

var timer : float = 0.0
var sizeScale : float = 1.0
var lifetimeScale : float = 1.0
var wasDocked : bool = false
var session : NetSession
#------------------------#


func _ready() -> void:
	timer = randf_range(spawnDelay.x, spawnDelay.y)

func _process(delta : float) -> void:
	if not boat:
		return
	var rod : FishingRod = player.heldItem as FishingRod if player else null
	sizeScale = rod.spot_size_scale() if rod else 1.0
	var sonar : int = BoatParts.tier(player.progress, BoatParts.SONAR) if player else 0
	lifetimeScale = (rod.spot_lifetime_scale() if rod else 1.0) * (1.0 + 0.2 * sonar)
	var pace : float = 1.0 + 0.3 * sonar
	var screen : Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	for spot : FishingSpot in get_children():
		spot.sizeScale = sizeScale
		spot.lifetimeScale = lifetimeScale
		spot.position.x -= boat.speed * delta
		if spot.global_position.x + spot.size - spot.radius < screen.position.x - screenMargin:
			spot.queue_free()
	if boat.docked != wasDocked:
		wasDocked = boat.docked
		timer = randf_range(dockedDelay.x, dockedDelay.y) if boat.docked else randf_range(spawnDelay.x, spawnDelay.y)
	# With a friend around, one game makes the spots and sends them over.
	if not session:
		session = NetSession.find(get_tree())
	if session and not session.spawns_spots():
		return
	if boat.docked:
		timer -= delta * pace
		if timer <= 0.0:
			timer = randf_range(dockedDelay.x, dockedDelay.y)
			if get_child_count() < dockedMaxSpots + (1 if sonar >= 2 else 0):
				spawn_docked(screen)
		return
	if boat.is_stopped():
		return
	timer -= delta * pace
	if timer <= 0.0:
		timer = randf_range(spawnDelay.x, spawnDelay.y)
		if get_child_count() < maxSpots + sonar:
			spawn(screen)

func new_spot() -> FishingSpot:
	var spot : FishingSpot = spotScene.instantiate()
	var biome : Biome = Ocean.current_biome(get_tree())
	if biome:
		spot.biome = biome
	spot.sizeScale = sizeScale
	spot.lifetimeScale = lifetimeScale
	return spot

func spawn(screen : Rect2) -> FishingSpot:
	var spot : FishingSpot = new_spot()
	var growth : float = spot.radius * (sizeScale - 1.0)
	for attempt in 16:
		var point : Vector2 = Vector2(screen.end.x + screenMargin + growth, randf_range(screen.position.y + screenMargin, screen.end.y - screenMargin))
		var band : float = point.y - boat.global_position.y
		if band > hullBand.x - growth * spot.squash and band < hullBand.y + growth * spot.squash:
			continue
		if spaced(point):
			add_child(spot)
			spot.global_position = point
			shared(spot)
			return spot
	spot.free()
	return null

func shared(spot : FishingSpot) -> void:
	if session:
		session.share_spot(spot)

# A spot the other player's game made (see NetSession.share_spot).
func add_shared(point : Vector2, life : float, biome : Biome) -> void:
	var spot : FishingSpot = new_spot()
	if biome:
		spot.biome = biome
	add_child(spot)
	spot.global_position = point
	spot.life = life

func clear_spots() -> void:
	for spot in get_children():
		spot.queue_free()

# Somewhere in open water on screen (islands have sea in several rooms),
# clear of the land and the hull.
func spawn_docked(screen : Rect2) -> FishingSpot:
	var island : Island = Island.current(get_tree())
	if not Ocean.current_biome(get_tree()):
		return null
	var spot : FishingSpot = new_spot()
	var reach : float = spot.radius * sizeScale
	var area : Rect2 = screen.grow(-screenMargin - reach)
	for attempt in 24:
		var point : Vector2 = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if spaced(point) and open_water(point, reach, spot.squash, island):
			add_child(spot)
			spot.global_position = point
			shared(spot)
			return spot
	spot.free()
	return null

func open_water(point : Vector2, reach : float, squash : float, island : Island) -> bool:
	var edge : float = reach + hullClearance
	for offset : Vector2 in [Vector2.ZERO, Vector2(edge, 0.0), Vector2(-edge, 0.0), Vector2(0.0, edge * squash), Vector2(0.0, -edge * squash)]:
		var at : Vector2 = point + offset
		if boat.covers(at) or boat.covers(at - Vector2(0.0, boat.deckHeight)) or (island and island.is_land(at)):
			return false
	return true

func spaced(point : Vector2) -> bool:
	return get_children().all(func(other : Node2D) -> bool: return other.global_position.distance_to(point) >= minSpacing * sizeScale)
