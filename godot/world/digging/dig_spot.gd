@tool
extends Interactable
class_name DigSpot

# The next spot of a treasure trail (see Digging), put down on the island by
# the DigMarker: a little X in the sand that glints. F digs it.

var player : Player
var time : float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	prompt = "Dig"
	reach = 9.0
	promptOffset = Vector2(0.0, -8.0)
	z_index = 0

func available(who : Player) -> bool:
	return Digging.active_here(who)

func blocked_reason(who : Player) -> String:
	return "" if Digging.best_spade(who) else "Needs a spade"

func prompt_text(who : Player) -> String:
	return "Dig" if blocked_reason(who).is_empty() else "Dig (needs a spade)"

func interact(who : Player) -> void:
	var found : String = Digging.dig(who)
	who.say(found, Digging.COLOR)
	Digging.place_spot(get_tree())

func _process(delta : float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var glow : float = 0.6 + 0.4 * sin(time * 4.0)
	var ink : Color = Color(0.35, 0.2, 0.1, 0.85)
	for i in range(-2, 3):
		draw_rect(Rect2(Vector2(i, i) - Vector2(0.5, 0.5), Vector2.ONE), ink)
		draw_rect(Rect2(Vector2(i, -i) - Vector2(0.5, 0.5), Vector2.ONE), ink)
	draw_rect(Rect2(Vector2(2.5, -4.5), Vector2.ONE), Color(1.0, 0.95, 0.7, glow))
