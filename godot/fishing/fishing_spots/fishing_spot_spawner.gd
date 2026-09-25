extends Node2D
class_name FishingSpotSpawner


#------------------------#
@export var boat : Boat
@export var spotScene : PackedScene
@export var maxSpots : int = 3
@export var spawnDelay : Vector2 = Vector2(2.0, 5.0)
@export var hullBand : Vector2 = Vector2(-2.0, 42.0)
@export var minSpacing : float = 24.0
@export var screenMargin : float = 12.0

var timer : float = 0.0
#------------------------#


func _ready() -> void:
	timer = randf_range(spawnDelay.x, spawnDelay.y)

func _process(delta : float) -> void:
	if not boat:
		return
	var screen : Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	for spot : Node2D in get_children():
		spot.position.x -= boat.speed * delta
		if spot.global_position.x < screen.position.x - screenMargin:
			spot.queue_free()
	if boat.is_stopped():
		return
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(spawnDelay.x, spawnDelay.y)
		if get_child_count() < maxSpots:
			spawn(screen)

func spawn(screen : Rect2) -> FishingSpot:
	for attempt in 16:
		var point : Vector2 = Vector2(screen.end.x + screenMargin, randf_range(screen.position.y + screenMargin, screen.end.y - screenMargin))
		var band : float = point.y - boat.global_position.y
		if band > hullBand.x and band < hullBand.y:
			continue
		if get_children().all(func(other : Node2D) -> bool: return other.global_position.distance_to(point) >= minSpacing):
			var spot : FishingSpot = spotScene.instantiate()
			add_child(spot)
			spot.global_position = point
			return spot
	return null
