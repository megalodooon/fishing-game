extends MenuPanel
class_name CharmPouchUI

# The charm pouch (hub tab): its slots on the left, the charms in the bag on
# the right. Click a charm in the bag to put it in the pouch, click one in the
# pouch to take it out. The pouch's Magical Power and what it gives sit under
# the slots; a charm outshone by a better one of its family is marked.

enum Zone { NONE, SLOT, LOCKED }
const VELVET : Color = Color(0.17, 0.1, 0.27)
const GOLD : Color = Color(0.86, 0.68, 0.32)
const LOCK : Texture2D = preload("res://ui/hub/icons/lock.png")
# Locked slots shown after the open ones, so the next goals are in sight.
const LOCKED_PREVIEW : int = 3

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin
@export var maxWidth : float = 184.0
# Full-size cells while the slots fit, smaller ones after that.
@export var bigCell : float = 19.0
@export var smallCell : float = 13.0
@export var gridWidth : float = 88.0

var cell : float = 19.0
var columns : int = 4

var list : ListMenu
var panel : Rect2
var gridRect : Rect2
var powerRect : Rect2
var slotRects : Array[Rect2] = []
var lockedRects : Array[Rect2] = []
var zone : Zone = Zone.NONE
var index : int = -1
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
	list.emptyText = "No charms in the bag"
	list.slide = Vector2.ZERO
	add_child(list)
	list.chosen.connect(put_in)
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
	gridRect = Rect2(inner.position + Vector2(0.0, 8.0), Vector2(gridWidth, inner.size.y - 8.0))
	var powerHeight : float = 4.0 * (ui.statSize + 1.0) + 7.0
	powerRect = Rect2(gridRect.end.x + 3.0, inner.end.y - powerHeight, inner.end.x - gridRect.end.x - 3.0, powerHeight)
	list.place(Rect2(Vector2(powerRect.position.x, inner.position.y), Vector2(powerRect.size.x, powerRect.position.y - inner.position.y - 2.0)))
	layout_slots()

func layout_slots() -> void:
	slotRects.clear()
	var count : int = CharmPouch.slots(player) if player and player.progress else CharmPouch.BASE_SLOTS
	var bigColumns : int = floori((gridWidth - 3.0) / bigCell)
	var fitsBig : bool = ceili(count / float(bigColumns)) * bigCell + 3.0 <= gridRect.size.y - 8.0
	cell = bigCell if fitsBig else smallCell
	columns = bigColumns if fitsBig else floori((gridWidth - 3.0) / smallCell)
	var left : float = floorf((gridRect.size.x - columns * cell) * 0.5) + 1.0
	lockedRects.clear()
	for i in count + LOCKED_PREVIEW:
		@warning_ignore("integer_division")
		var area : Rect2 = Rect2(gridRect.position + Vector2(left + (i % columns) * cell, 3.0 + (i / columns) * cell), Vector2(cell - 1.0, cell - 1.0))
		if i < count:
			slotRects.append(area)
		elif area.end.y <= gridRect.end.y - 8.0:
			lockedRects.append(area)
	queue_redraw()

# The next Angler Level that opens another slot.
func next_slot_level() -> int:
	var every : int = AnglerLevel.POUCH_EVERY
	return (floori(AnglerLevel.level(player) / float(every)) + 1) * every

func hub_open() -> void:
	if not shown:
		MenuHub.menu_opened(get_tree(), self)
		player.frozen = true
		layout_slots()
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

# Charms in the bag, the ones outshone by a better one of their family dimmed.
func refresh() -> void:
	if not shown and not visible:
		return
	var counted : Array[Charm] = CharmPouch.counted(player)
	var rows : Array[Dictionary] = []
	for slot in player.inventory.trashSlot:
		var charm : Charm = player.inventory.items[slot] as Charm
		if charm:
			var active : bool = counted.has(charm.original())
			rows.append({"value": slot, "icon": charm.icon, "text": charm.displayName, "detail": "+%d MP" % CharmPouch.power_of(charm), "detailColor": skin.accent if active else skin.dim, "dim": not active})
	list.set_rows(rows)
	queue_redraw()

func put_in(value : Variant) -> void:
	if not value is int:
		return
	if player.progress.charms.size() >= CharmPouch.slots(player):
		list.flash(value)
		return
	var charm : Item = player.inventory.get_item(value)
	if not charm is Charm:
		return
	player.inventory.items[value] = null
	player.progress.charms.append(charm)
	CharmPouch.dirty()
	AnglerLevel.forget()
	player.inventory.emit_changed()
	var at : int = player.progress.charms.size() - 1
	if at < slotRects.size():
		sparkles.burst(slotRects[at].get_center(), skin.accent, 10)

func take_out(at : int) -> void:
	if at >= player.progress.charms.size():
		return
	var charm : Item = player.progress.charms[at]
	if player.inventory.room_for(charm) <= 0:
		return
	player.progress.charms.remove_at(at)
	player.inventory.add(charm)
	CharmPouch.dirty()
	AnglerLevel.forget()
	player.inventory.emit_changed()

# The pouch lining: dark velvet with a stitched gold seam.
func draw_velvet(area : Rect2) -> void:
	draw_rect(area, Color(0.06, 0.03, 0.08))
	draw_rect(area.grow(-1.0), VELVET)
	for x in range(int(area.position.x) + 3, int(area.end.x) - 3, 3):
		draw_rect(Rect2(x, area.position.y + 1.0, 1.0, 1.0), Color(GOLD, 0.35))
		draw_rect(Rect2(x, area.end.y - 8.0, 1.0, 1.0), Color(GOLD, 0.35))
	for y in range(int(area.position.y) + 3, int(area.end.y) - 8, 3):
		draw_rect(Rect2(area.position.x + 1.0, y, 1.0, 1.0), Color(GOLD, 0.35))
		draw_rect(Rect2(area.end.x - 2.0, y, 1.0, 1.0), Color(GOLD, 0.35))

# A socket for one charm: a gold rim, lit from above, and a sunken middle.
func draw_socket(area : Rect2, hover : bool) -> void:
	var rim : Color = GOLD.lightened(0.15) if hover else GOLD
	draw_rect(area, Color(0.1, 0.06, 0.03))
	draw_rect(area.grow(-1.0), rim.darkened(0.3))
	draw_rect(Rect2(area.position + Vector2(1.0, 1.0), Vector2(area.size.x - 2.0, 1.0)), rim)
	draw_rect(Rect2(area.position + Vector2(1.0, 1.0), Vector2(1.0, area.size.y - 2.0)), rim.darkened(0.1))
	draw_rect(area.grow(-2.0), VELVET.darkened(0.35))
	draw_rect(Rect2(area.position + Vector2(2.0, 2.0), Vector2(area.size.x - 4.0, 1.0)), VELVET.darkened(0.6))

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		zone = Zone.NONE
		queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		zone = Zone.NONE
		for i in slotRects.size():
			if slotRects[i].has_point(mouse):
				zone = Zone.SLOT
				index = i
		for i in lockedRects.size():
			if lockedRects[i].has_point(mouse):
				zone = Zone.LOCKED
				index = i
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT and zone == Zone.SLOT:
			take_out(index)
	accept_event()

func _process(delta : float) -> void:
	time += delta
	# The glow breathes and the empty-slot hint blinks, so it keeps drawing
	# while open; it's one small panel.
	queue_redraw()
	sparkles.update(delta)

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	var used : int = player.progress.charms.size()
	UiKit.label(self, font, Vector2(gridRect.position.x, gridRect.position.y - 2.0), "Charm pouch", ui.titleSize, skin.title)
	UiKit.label(self, font, Vector2(gridRect.position.x, gridRect.position.y - 2.0), "%d/%d" % [used, slotRects.size()], ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, gridRect.size.x)
	draw_velvet(gridRect)
	var counted : Array[Charm] = CharmPouch.counted(player)
	for i in slotRects.size():
		var hover : bool = zone == Zone.SLOT and index == i
		var area : Rect2 = slotRects[i]
		var charm : Charm = player.progress.charms[i] as Charm if i < used else null
		draw_socket(area, hover)
		if charm:
			var active : bool = counted.has(charm.original())
			var lift : Vector2 = Vector2(0.0, -1.0 if hover else 0.0)
			var glow : Color = charm.rarity.color if charm.rarity else Color.WHITE
			if active:
				draw_circle(area.get_center() + lift, (cell - 4.0) * 0.5, Color(glow, 0.22 + 0.08 * sin(time * 3.0 + i)), true)
			ui.draw_icon(self, charm.icon, area.get_center() + lift, Color.WHITE if active else Color(0.55, 0.5, 0.6, 0.55), ui.outline_color(charm), minf(1.0, (cell - 3.0) / maxf(charm.icon.get_width(), charm.icon.get_height())))
			if charm.tier > 0 and not charm.family.is_empty():
				for p in charm.tier:
					draw_rect(Rect2(area.end.x - 3.0 - p * 2.0, area.end.y - 3.0, 1.0, 1.0), GOLD.lightened(0.3))
			if not active:
				draw_rect(Rect2(area.position.x + 2.0, area.position.y + 2.0, 3.0, 1.0), Color(0.95, 0.45, 0.4))
		elif not list.rows.is_empty() and fmod(time, 1.6) < 0.8:
			var center : Vector2 = area.get_center().floor()
			draw_rect(Rect2(center + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(GOLD, 0.45))
			draw_rect(Rect2(center + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(GOLD, 0.45))
		if hover:
			UiKit.brackets(self, area, skin.title, time)
	for i in lockedRects.size():
		var area : Rect2 = lockedRects[i]
		draw_rect(area, Color(0.05, 0.03, 0.08))
		draw_rect(area.grow(-1.0), Color(0.1, 0.07, 0.14))
		draw_texture(LOCK, (area.get_center() - LOCK.get_size() * 0.5).floor(), Color(1.0, 1.0, 1.0, 0.35 if not (zone == Zone.LOCKED and index == i) else 0.8))
	UiKit.label(self, font, Vector2(gridRect.position.x, gridRect.end.y - 3.0), "Best of each family counts", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_CENTER, gridRect.size.x)
	UiKit.box(self, skin.well, powerRect)
	var inner : Rect2 = powerRect.grow(-3.0)
	var power : int = CharmPouch.magical_power(player)
	var y : float = inner.position.y
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "Magical Power", ui.statSize, skin.dim)
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "%d" % power, ui.statSize, skin.accent, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	y += ui.statSize + 3.0
	for stat in CharmPouch.PER_POWER:
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), Stats.name_of(stat), ui.statSize, skin.text)
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), Stats.bonus_text(stat, CharmPouch.bonus(player, stat)), ui.statSize, skin.good, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += ui.statSize + 1.0
	sparkles.draw(self)
	if zone == Zone.LOCKED:
		var lines : PackedStringArray = PackedStringArray(["Opens at", "Angler Level %d" % next_slot_level(), "Or sooner with", "Pouch Stitching"])
		ui.paint_tip(self, mouse, "Locked slot", ui.dimColor, lines, ui.tip_size("Locked slot", lines))
	if zone == Zone.SLOT and index < used:
		var charm : Charm = player.progress.charms[index] as Charm
		if charm:
			var lines : PackedStringArray = charm.details()
			lines.append_array(["Click", "take out"])
			ui.paint_tip(self, mouse, charm.displayName, charm.title_color(), lines, ui.tip_size(charm.displayName, lines, charm.tag()), charm.tag())
