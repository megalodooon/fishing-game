extends Node2D
class_name EventPickup

# Something a festival left lying around an island, like a present in the
# snow. It bobs and glints, and walking into it picks it up. Each one is
# found once per day (Progress.pickups), so every island is worth a walk
# while the festival runs.

const REACH : float = 7.0

#------------------------#
var item : Item
var art : Texture2D
var key : String = ""
var player : Player
var time : float = 0.0
var taken : float = -1.0
#------------------------#


func _ready() -> void:
	player = Player.find(get_tree())
	time = randf() * TAU
	z_index = 1

func _process(delta : float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	if taken >= 0.0:
		taken += delta
		if taken > 0.4:
			queue_free()
	elif player and player.global_position.distance_to(global_position) < REACH:
		collect()
	queue_redraw()

func collect() -> void:
	if not item or not player.inventory.room_for(item) > 0:
		return
	taken = 0.0
	player.inventory.give(item, 1)
	player.progress.pickups[key] = true
	player.progress.count("pickups")
	player.say("+1 %s" % item.displayName, Color(1.0, 0.86, 0.36))

func _draw() -> void:
	var texture : Texture2D = art if art else (item.icon if item else null)
	if not texture:
		return
	var lift : float = sin(time * 2.4) * 1.0 - (taken * 20.0 if taken >= 0.0 else 0.0)
	var fade : float = 1.0 - clampf(taken / 0.4, 0.0, 1.0) if taken >= 0.0 else 1.0
	draw_rect(Rect2(-3.0, 1.0, 6.0, 1.0), Color(0.0, 0.0, 0.0, 0.25 * fade))
	draw_texture(texture, (Vector2(-texture.get_width() * 0.5, -texture.get_height() + lift)).round(), Color(1.0, 1.0, 1.0, fade))
	var glint : float = maxf(sin(time * 3.0), 0.0)
	if glint > 0.8:
		draw_rect(Rect2(Vector2(texture.get_width() * 0.25, -texture.get_height() + lift).round(), Vector2.ONE), Color(1.0, 1.0, 1.0, (glint - 0.8) * 5.0 * fade))
