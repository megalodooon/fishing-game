@tool
extends Interactable
class_name ArcadeStand

# A dart board in the tavern, the regatta flag on the east pier, or the
# lantern toss booth that only opens while a festival is on. Drawn as simple
# placeholder shapes. Using it opens the game (see ArcadeUI).

const NAMES : PackedStringArray = ["Play darts", "Race the harbor", "Lantern toss"]

#------------------------#
@export_enum("Darts", "Race", "Toss") var game : int = 0
#------------------------#


func available(_player : Player) -> bool:
	return game != ArcadeUI.TOSS or Engine.is_editor_hint() or ArcadeUI.festival(get_tree()) != null

func prompt_text(player : Player) -> String:
	return NAMES[game] if blocked_reason(player).is_empty() else super(player)

func interact(player : Player) -> void:
	ArcadeUI.open(get_tree(), player, game)

# Only the booth changes, when a festival starts or ends.
func _ready() -> void:
	set_process(game == ArcadeUI.TOSS)

func _process(_delta : float) -> void:
	queue_redraw()

func _draw() -> void:
	var open : bool = available(null)
	match game:
		ArcadeUI.DARTS:
			draw_circle(Vector2(0.0, -10.0), 6.0, Color(0.16, 0.12, 0.1))
			draw_circle(Vector2(0.0, -10.0), 5.0, Color(0.92, 0.88, 0.76))
			draw_circle(Vector2(0.0, -10.0), 3.0, Color(0.2, 0.55, 0.3))
			draw_circle(Vector2(0.0, -10.0), 1.0, Color(0.85, 0.2, 0.2))
		ArcadeUI.RACE:
			draw_rect(Rect2(-1.0, -16.0, 1.0, 16.0), Color(0.45, 0.32, 0.2))
			for i in 4:
				draw_rect(Rect2(float(i % 2) * 2.0, -16.0 + floorf(i / 2.0) * 2.0, 2.0, 2.0), Color.WHITE if (i + int(i / 2.0)) % 2 == 0 else Color(0.1, 0.1, 0.12))
				draw_rect(Rect2(4.0 + float(i % 2) * 2.0, -16.0 + floorf(i / 2.0) * 2.0, 2.0, 2.0), Color(0.1, 0.1, 0.12) if (i + int(i / 2.0)) % 2 == 0 else Color.WHITE)
		ArcadeUI.TOSS:
			if not open:
				return
			draw_rect(Rect2(-9.0, -6.0, 18.0, 6.0), Color(0.5, 0.33, 0.2))
			for i in 6:
				draw_rect(Rect2(-9.0 + i * 3.0, -14.0, 3.0, 3.0), Color(0.9, 0.3, 0.3) if i % 2 == 0 else Color(0.96, 0.92, 0.82))
			draw_rect(Rect2(-9.0, -11.0, 1.0, 5.0), Color(0.4, 0.26, 0.16))
			draw_rect(Rect2(8.0, -11.0, 1.0, 5.0), Color(0.4, 0.26, 0.16))
			draw_circle(Vector2(0.0, -9.0), 1.5, Color(1.0, 0.8, 0.35))
	super()
