extends MenuPanel
class_name EquipmentUI

# What the player wears (hub tab, O): on the left the four slots around the
# player (hat on top, gear in the middle, two charms below) and a summary of
# everything worn adds; on the right what in the bag can be worn. Click
# something in the list to put it on (what it replaces goes back in the bag),
# click a slot to take it off. Magical Power from the charm collection sits
# under the summary.

enum Zone { NONE, SLOT }
const VELVET : Color = Color(0.13, 0.11, 0.2)
const GOLD : Color = Color(0.86, 0.68, 0.32)

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin
@export var maxWidth : float = 184.0

var list : ListMenu
var panel : Rect2
var doll : Rect2
var summaryRect : Rect2
var slotRects : Dictionary = {}
var hovered : String = ""
var mouse : Vector2 = Vector2(-100.0, -100.0)
var time : float = 0.0
var sparkles : Sparkles = Sparkles.new()
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/leather_blue.tres") as MenuSkin
	list = ListMenu.new()
	list.ui = ui
	list.skin = skin
	list.searchable = false
	list.emptyText = "Nothing to wear in the bag"
	list.slide = Vector2.ZERO
	add_child(list)
	list.chosen.connect(put_on)
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	player.inventory.changed.connect(refresh)
	set_process(false)
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	var width : float = minf(ui.size.x - 6.0, maxWidth)
	var top : float = MenuHub.top_of(get_tree(), 3.0) if is_inside_tree() else 3.0
	panel = Rect2(floorf((ui.size.x - width) * 0.5), top, width, ui.size.y - top - 2.0)
	var inner : Rect2 = panel.grow(-5.0)
	doll = Rect2(inner.position, Vector2(84.0, 50.0))
	summaryRect = Rect2(inner.position.x, doll.end.y + 3.0, doll.size.x, inner.end.y - doll.end.y - 3.0)
	list.place(Rect2(Vector2(doll.end.x + 4.0, inner.position.y), Vector2(inner.end.x - doll.end.x - 4.0, inner.size.y)))
	var middle : float = doll.get_center().x
	var cell : Vector2 = Vector2(16.0, 16.0)
	slotRects = {
		"hat": Rect2(Vector2(middle - 8.0, doll.position.y + 2.0), cell),
		"gear": Rect2(Vector2(middle - 8.0, doll.position.y + 19.0), cell),
		"charm1": Rect2(Vector2(middle - 30.0, doll.position.y + 30.0), cell),
		"charm2": Rect2(Vector2(middle + 14.0, doll.position.y + 30.0), cell),
	}
	queue_redraw()

func hub_open() -> void:
	if not shown:
		MenuHub.menu_opened(get_tree(), self)
		player.frozen = true
		refresh()
		open_menu()
		list.open_menu()
		set_process(true)

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func close() -> void:
	if not shown:
		return
	close_menu()
	list.close_menu()
	set_process(false)
	player.frozen = false

func _unhandled_input(event : InputEvent) -> void:
	if shown and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(1.0).has_point(point)

# Everything in the bag that can be worn, by slot.
func refresh() -> void:
	if not shown:
		return
	var rows : Array[Dictionary] = []
	for slot in player.inventory.items.size():
		var item : Item = player.inventory.get_item(slot)
		if item and Equipment.can_wear(item):
			var into : String = Equipment.slot_for(player, item)
			var replacing : Item = Equipment.worn(player, into)
			rows.append({"value": slot, "text": item.displayName, "icon": item.icon, "outline": ui.outline_color(item), "detail": Equipment.SLOT_NAMES[into] + (" (swap)" if replacing else ""), "detailColor": skin.dim})
	list.set_rows(rows)
	queue_redraw()

func put_on(value : Variant) -> void:
	var item : Item = player.inventory.get_item(int(value))
	var into : String = Equipment.slot_for(player, item) if item else ""
	if Equipment.equip(player, int(value)) and slotRects.has(into):
		sparkles.burst((slotRects[into] as Rect2).get_center(), GOLD, 10)
	refresh()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		hovered = ""
		for slot in slotRects:
			if (slotRects[slot] as Rect2).has_point(mouse):
				hovered = slot
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not hovered.is_empty():
			if Equipment.unequip(player, hovered):
				sparkles.burst((slotRects[hovered] as Rect2).get_center(), skin.dim, 6)
			refresh()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	sparkles.update(delta)
	queue_redraw()

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	# The slots on velvet, around a figure.
	draw_rect(doll, VELVET)
	UiKit.outline(self, doll, GOLD.darkened(0.4))
	var figure : Texture2D = player.sprite.texture
	if figure:
		draw_texture(figure, (doll.get_center() + Vector2(-figure.get_width() * 0.5, -figure.get_height() * 0.5 + 6.0)).floor(), Color(1.0, 1.0, 1.0, 0.25))
	for slot in slotRects:
		var area : Rect2 = slotRects[slot]
		var item : Item = Equipment.worn(player, slot)
		draw_rect(area, Color(0.05, 0.04, 0.08))
		UiKit.outline(self, area, GOLD if item else GOLD.darkened(0.5))
		if item and item.icon:
			ui.draw_icon(self, item.icon, area.get_center(), Color.WHITE, ui.outline_color(item), minf(1.0, (area.size.x - 3.0) / maxf(item.icon.get_width(), item.icon.get_height())))
		else:
			UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, 3)), Equipment.SLOT_NAMES[slot], 3, Color(GOLD, 0.45), HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
		if slot == hovered:
			UiKit.brackets(self, area, skin.title, time)
	draw_summary(font)
	sparkles.draw(self)
	# The worn thing under the pointer.
	if not hovered.is_empty():
		var item : Item = Equipment.worn(player, hovered)
		if item:
			var lines : PackedStringArray = item.details()
			lines.append_array(["Click to take it off", ""])
			ui.paint_tip(self, mouse, item.displayName, item.title_color(), lines, ui.tip_size(item.displayName, lines, item.tag()), item.tag())

# Everything worn adds up to this, plus Magical Power and when bedtime is.
func draw_summary(font : Font) -> void:
	UiKit.box(self, skin.well, summaryRect)
	var x : float = summaryRect.position.x + 3.0
	var width : float = summaryRect.size.x - 6.0
	var y : float = summaryRect.position.y + 2.0
	UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), "What it adds", 3, skin.title)
	y += 5.0
	var totals : Dictionary = {}
	for item in Equipment.worn_items(player):
		var stats : Dictionary = item.get("stats") if item.get("stats") != null else {}
		for stat in stats:
			totals[stat] = totals.get(stat, 0.0) + float(stats[stat])
	for stat in totals:
		if y > summaryRect.end.y - 12.0:
			break
		UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), Stats.name_of(stat), 3, skin.text, HORIZONTAL_ALIGNMENT_LEFT, width - 16.0)
		UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), Stats.bonus_text(stat, totals[stat]), 3, skin.good, HORIZONTAL_ALIGNMENT_RIGHT, width)
		y += 4.0
	for item in Equipment.worn_items(player):
		if item is Gear and not (item as Gear).unique_effect.is_empty():
			for line in ui.wrap_lines(Equipment.UNIQUES.get((item as Gear).unique_effect, ""), width, 3):
				if y > summaryRect.end.y - 12.0:
					break
				UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), line, 3, Color(0.95, 0.82, 0.45))
				y += 4.0
	if totals.is_empty():
		UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), "Nothing worn yet", 3, skin.dim)
	var power : int = Equipment.magical_power(player)
	var bottom : float = summaryRect.end.y - 6.0
	UiKit.label(self, font, Vector2(x, bottom + font.get_ascent(3) - 4.0), "Magical Power %d" % power, 3, Color(0.75, 0.55, 1.0), HORIZONTAL_ALIGNMENT_LEFT, width)
	UiKit.label(self, font, Vector2(x, bottom + font.get_ascent(3)), "from every charm found", 3, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, width)
