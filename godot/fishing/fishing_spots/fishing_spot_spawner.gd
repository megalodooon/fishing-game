extends Node2D
class_name FishingSpotSpawner


#------------------------#
@export var boat : Boat
@export var player : Player
@export var spotScene : PackedScene
@export var maxSpots : int = 3
@export var spawnDelay : Vector2 = Vector2(2.0, 5.0)
@export var hullBand : Vector2 = Vector2(-2.0, 42.0)
@export var minSpacing : float = 24.0
@export var screenMargin : float = 12.0

var timer : float = 0.0
var sizeScale : float = 1.0
var lifetimeScale : float = 1.0
#------------------------#


func _ready() -> void:
	timer = randf_range(spawnDelay.x, spawnDelay.y)

func _process(delta : float) -> void:
	if not boat:
		return
	var rod : FishingRod = player.heldItem as FishingRod if player else null
	sizeScale = rod.spot_size_scale() if rod else 1.0
	lifetimeScale = rod.spot_lifetime_scale() if rod else 1.0
	var screen : Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	for spot : FishingSpot in get_children():
		spot.sizeScale = sizeScale
		spot.lifetimeScale = lifetimeScale
		spot.position.x -= boat.speed * delta
		if spot.global_position.x + spot.size - spot.radius < screen.position.x - screenMargin:
			spot.queue_free()
	if boat.is_stopped():
		return
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(spawnDelay.x, spawnDelay.y)
		if get_child_count() < maxSpots:
			spawn(screen)

func spawn(screen : Rect2) -> FishingSpot:
	var spot : FishingSpot = spotScene.instantiate()
	var biome : Biome = Ocean.current_biome(get_tree())
	if biome:
		spot.fish = biome.fish
	var growth : float = spot.radius * (sizeScale - 1.0)
	for attempt in 16:
		var point : Vector2 = Vector2(screen.end.x + screenMargin + growth, randf_range(screen.position.y + screenMargin, screen.end.y - screenMargin))
		var band : float = point.y - boat.global_position.y
		if band > hullBand.x - growth * spot.squash and band < hullBand.y + growth * spot.squash:
			continue
		if get_children().all(func(other : Node2D) -> bool: return other.global_position.distance_to(point) >= minSpacing * sizeScale):
			spot.sizeScale = sizeScale
			spot.lifetimeScale = lifetimeScale
			add_child(spot)
			spot.global_position = point
			return spot
	spot.free()
	return null
