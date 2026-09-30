@tool
extends Interactable
class_name Secret

# Something to find: a buried chest, a bottle with a note, a loose plank. It
# hands out its items and coins and shows its message once. Hidden ones are
# nothing but a glint now and then until they're found, then they're gone.
# Repeatable ones (signs, notes on a wall) can be read again and again.

#------------------------#
# Remembers it was found. Empty uses the node's path.
@export var flag : String = ""
@export var title : String = "Found something!"
@export_multiline var message : String = ""
@export var items : Array[Item] = []
# How many of each item, at the same index. 1 when left out.
@export var amounts : Array[int] = []
@export var coins : int = 0
@export var repeatable : bool = false
@export var concealed : bool = true
@export var foundColor : Color = Color(1.0, 0.9, 0.4)

@export_group("Glint")
@export var glintColor : Color = Color(1.0, 0.98, 0.85)
@export var glintEvery : Vector2 = Vector2(2.0, 5.0)
@export var glintTime : float = 0.35

var player : Player
var glintTimer : float = 0.0
var glinting : float = 0.0
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	glintTimer = randf_range(glintEvery.x, glintEvery.y)
	if found():
		visible = not concealed

func key() -> String:
	return "secret/" + (flag if not flag.is_empty() else String(get_path()))

func found() -> bool:
	return not repeatable and player != null and player.progress != null and player.progress.has_flag(key())

func available(_player : Player) -> bool:
	return not found()

func interact(who : Player) -> void:
	if found():
		return
	var got : PackedStringArray = PackedStringArray()
	for i in items.size():
		var item : Item = items[i]
		var amount : int = amounts[i] if i < amounts.size() else 1
		if item and not Counter.fits(who, item, amount):
			notice("Bag full", "Make room before picking this up.", blockedColor)
			return
	for i in items.size():
		var item : Item = items[i]
		var amount : int = amounts[i] if i < amounts.size() else 1
		if item:
			Counter.deliver(who, item, amount)
			got.append(item.displayName if amount <= 1 else "%s x%d" % [item.displayName, amount])
	if coins > 0:
		who.wallet.add(coins)
		got.append("$%d" % coins)
	var text : String = message
	if not got.is_empty():
		text = ("Got " + ", ".join(got) + ". " + text).strip_edges()
	notice(title, text, foundColor)
	if not repeatable:
		who.progress.set_flag(key())
		if flag.begins_with("pearl_"):
			who.progress.count("pearls")
		if concealed:
			visible = false

func _process(delta : float) -> void:
	if Engine.is_editor_hint() or not concealed:
		return
	glinting = maxf(glinting - delta, 0.0)
	glintTimer -= delta
	if glintTimer <= 0.0:
		glintTimer = randf_range(glintEvery.x, glintEvery.y)
		glinting = glintTime
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		super()
		return
	if not concealed or glinting <= 0.0:
		return
	var t : float = sin(glinting / glintTime * PI)
	var arm : float = roundf(t * 2.0)
	var color : Color = Color(glintColor, t)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), color)
	if arm > 0.0:
		for direction : Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(direction * arm, Vector2.ONE), Color(glintColor, t * 0.6))
