extends MenuPanel
class_name TackleboxUI

# The selected rod in the middle of a ring of its tackle slots. The header
# shows the rod and a button that opens a searchable list of every rod. The
# parts that fit the selected slot sit in a searchable, sortable list on the
# right, with the rod's stats below it. Hovering a part previews what it
# changes. Changes reach the rod in hand when the tacklebox closes.

enum Zone { NONE, ROD, SLOT, CHANGE, CLOSE }
# The value of the list row that takes the part off.
const EMPTY : StringName = &"empty"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
# Drawn faintly in empty slots, in Tackle.Kind order.
@export var kindIcons : Array[Texture2D] = []
@export var skin : MenuSkin

@export_group("Layout")
@export var maxWidth : int = 188
@export var edge : int = 2
@export var padding : int = 5
@export var ringWidth : int = 84
@export var rodScale : float = 2.0
@export var pickerSize : Vector2 = Vector2(110, 80)

@export_group("Colors")
@export var ringColor : Color = Color(0.7, 0.95, 0.85, 0.35)
@export var betterColor : Color = Color(0.56, 0.93, 0.44)
@export var worseColor : Color = Color(0.95, 0.38, 0.34)
@export var shadeColor : Color = Color(0.02, 0.04, 0.08, 0.6)

var inventory : Inventory
var box : Tacklebox
var parts : ListMenu
var rodPicker : ListMenu
var tipLayer : Control
var rods : PackedInt32Array = PackedInt32Array()
var rod : RodItem
var slot : int = 0
var zone : Zone = Zone.NONE
var index : int = -1
var locked : bool = false
var panelRect : Rect2
var rodRect : Rect2
var changeRect : Rect2
var closeRect : Rect2
var statsRect : Rect2
var center : Vector2
var radius : float = 0.0
var slotRects : Array[Rect2] = []
var base : Array = []
var preview : Array = []
var tipTitle : String = ""
var tipSub : String = ""
var tipColor : Color = Color.WHITE
var tipLines : PackedStringArray = PackedStringArray()
var tipSize : Vector2 = Vector2.ZERO
var tipLeftOf : float = -1.0
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	inventory = player.inventory
	box = player.tacklebox
	if not skin:
		skin = load("res://ui/skins/themes/tin.tres") as MenuSkin
	parts = make_list(false)
	parts.chosen.connect(choose_part)
	parts.pointed.connect(point_part)
	parts.set_sorts(PackedStringArray(["Found", "Name", "Free"]), [
		func(a : Dictionary, b : Dictionary) -> bool: return a.known if a.known != b.known else a.order < b.order,
		func(a : Dictionary, b : Dictionary) -> bool: return a.known if a.known != b.known else a.text.naturalnocasecmp_to(b.text) < 0,
		func(a : Dictionary, b : Dictionary) -> bool: return a.spare > b.spare if a.spare != b.spare else a.order < b.order,
	] as Array[Callable])
	parts.open_menu()
	rodPicker = make_list(true)
	rodPicker.title = "Rods"
	rodPicker.chosen.connect(choose_rod)
	rodPicker.pointed.connect(point_rod)
	rodPicker.set_sorts(PackedStringArray(["Bag", "Name", "Slots"]), [
		func(a : Dictionary, b : Dictionary) -> bool: return a.value < b.value,
		func(a : Dictionary, b : Dictionary) -> bool: return a.text.naturalnocasecmp_to(b.text) < 0,
		func(a : Dictionary, b : Dictionary) -> bool: return a.slots > b.slots if a.slots != b.slots else a.value < b.value,
	] as Array[Callable])
	tipLayer = Control.new()
	tipLayer.mouse_filter = MOUSE_FILTER_IGNORE
	tipLayer.draw.connect(draw_tip)
	add_child(tipLayer)
	set_process(false)
	inventory.changed.connect(refresh)
	box.changed.connect(refresh)
	ui.opened.connect(close)
	ui.laid_out.connect(fit)
	fit()

func make_list(popup : bool) -> ListMenu:
	var list : ListMenu = ListMenu.new()
	list.ui = ui
	list.skin = skin
	list.framed = true
	list.slide = Vector2(0.0, 6.0) if popup else Vector2.ZERO
	add_child(list)
	return list

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	layout()
	refresh()

func _process(_delta : float) -> void:
	if is_locked() != locked:
		locked = not locked
		queue_redraw()
	if tipSize != Vector2.ZERO:
		tipLayer.queue_redraw()
	parts.modulate = Color(0.55, 0.55, 0.55) if rodPicker.shown else Color.WHITE

func _unhandled_input(event : InputEvent) -> void:
	if shown and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if rodPicker.shown:
			rodPicker.close_menu()
		else:
			close()

func _has_point(point : Vector2) -> bool:
	return shown and panelRect.has_point(point)

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover(Vector2i(Zone.NONE, -1))

func hub_open() -> void:
	if not shown:
		toggle()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func toggle() -> void:
	if shown:
		close()
	else:
		ui.close()
		open_menu()
		set_process(true)
		refresh()

func close() -> void:
	if shown:
		rodPicker.close_menu()
		close_menu()
		set_process(false)
		clear_tip()
		if player.heldItem is FishingRod:
			(player.heldItem as FishingRod).apply_tackle()

func refresh() -> void:
	if not shown:
		return
	rods.clear()
	for i in inventory.catchSlot:
		if inventory.items[i] is RodItem:
			rods.append(i)
	if rod_slot() < 0:
		rod = player.held_data() as RodItem if player.held_data() is RodItem else null
		if not rod and not rods.is_empty():
			rod = inventory.items[rods[0]]
	base = []
	if rod:
		slot = clampi(slot, 0, rod.slots.size() - 1)
		base = rod.stat_rows(rod.tackle)
	locked = is_locked()
	layout()
	fill_parts()
	fill_rods()
	hover(zone_at(get_local_mouse_position()), true)
	queue_redraw()

func fill_parts() -> void:
	var list : Array[Dictionary] = []
	var top : Array[Dictionary] = []
	if rod:
		var kind : Tackle.Kind = rod.slots[slot]
		var here : Tackle = rod.tackle[slot]
		var order : int = 0
		for part in box.parts_of(kind):
			var owned : int = box.count(part)
			var spare : int = box.free_count(part, inventory)
			if not box.knows(part):
				list.append({"value": part, "icon": part.icon, "tint": Color(0.0, 0.0, 0.0, 0.6), "text": "???", "search": "", "dim": true, "known": false, "order": order, "spare": -1})
			else:
				var usable : bool = spare > 0 or part == here
				list.append({"value": part, "icon": part.icon, "tint": part.icon_tint(), "text": part.displayName, "detail": "%d/%d" % [spare, owned], "detailColor": ui.dimColor if usable else worseColor, "dim": not usable, "marked": part == here, "known": true, "order": order, "spare": spare})
			order += 1
		if not rod.is_required(slot):
			top.append({"value": EMPTY, "cross": true, "text": "Empty", "marked": here == null})
		parts.search.placeholder_text = "Search %ss" % Tackle.KIND_NAMES[kind].to_lower()
	parts.set_rows(list, top)

func fill_rods() -> void:
	var list : Array[Dictionary] = []
	for i in rods:
		var item : RodItem = inventory.items[i]
		var busy : bool = not player.can_move_slot(i)
		list.append({"value": i, "icon": item.icon, "text": item.displayName, "detail": "in use" if busy else "%d slots" % item.slots.size(), "detailColor": worseColor if busy else ui.dimColor, "marked": item == rod, "slots": item.slots.size()})
	rodPicker.set_rows(list)

func rod_slot() -> int:
	for i in rods:
		if inventory.items[i] == rod:
			return i
	return -1

func is_locked() -> bool:
	return rod != null and not player.can_move_slot(rod_slot())

func layout() -> void:
	var width : float = minf(size.x - edge * 2.0, maxWidth)
	var top : float = MenuHub.top_of(get_tree(), edge) if is_inside_tree() else float(edge)
	panelRect = Rect2(floorf((size.x - width) * 0.5), top, width, size.y - top - edge)
	var inner : Rect2 = panelRect.grow(-padding)
	var s : float = ui.slotSize
	rodRect = Rect2(inner.position, Vector2(s, s))
	closeRect = Rect2(inner.end.x - s, inner.position.y, s, s)
	var label : float = ui.font.get_string_size("Change rod", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 6.0
	changeRect = Rect2(closeRect.position.x - 2.0 - label, inner.position.y, label, s)
	var bodyTop : float = inner.position.y + s + 3.0
	var left : Rect2 = Rect2(inner.position.x, bodyTop, ringWidth, inner.end.y - bodyTop)
	center = left.get_center().round()
	radius = floorf(minf(left.size.x, left.size.y) * 0.5 - s * 0.5 - 1.0)
	slotRects.clear()
	if rod:
		for i in rod.slots.size():
			var point : Vector2 = center + Vector2.from_angle(-PI * 0.5 + TAU * i / rod.slots.size()) * radius
			slotRects.append(Rect2((point - Vector2.ONE * s * 0.5).round(), Vector2.ONE * s))
	var right : Rect2 = Rect2(left.end.x + 4.0, bodyTop, inner.end.x - left.end.x - 4.0, left.size.y - 1.0)
	var statsHeight : float = FishingRod.STAT_NAMES.size() * (ui.statSize + 1.0) + 1.0
	statsRect = Rect2(right.position.x, right.end.y - statsHeight, right.size.x, statsHeight)
	parts.place(Rect2(right.position, Vector2(right.size.x, right.size.y - statsHeight - 3.0)))
	rodPicker.place(Rect2(((size - pickerSize) * 0.5).floor(), pickerSize))
	tipLayer.size = size
	queue_redraw()

func zone_at(point : Vector2) -> Vector2i:
	if not shown or rodPicker.shown:
		return Vector2i(Zone.NONE, -1)
	if closeRect.has_point(point):
		return Vector2i(Zone.CLOSE, 0)
	if changeRect.has_point(point):
		return Vector2i(Zone.CHANGE, 0)
	if rodRect.has_point(point):
		return Vector2i(Zone.ROD, 0)
	for i in slotRects.size():
		if slotRects[i].has_point(point):
			return Vector2i(Zone.SLOT, i)
	return Vector2i(Zone.NONE, -1)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover(zone_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
		if rodPicker.shown:
			rodPicker.close_menu()
		else:
			var at : Vector2i = zone_at(event.position)
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					click(at)
				MOUSE_BUTTON_RIGHT:
					if at.x == Zone.SLOT:
						set_part(at.y, null)
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					if rod and event.position.x < statsRect.position.x:
						select_slot(wrapi(slot + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 0, rod.slots.size()))
		accept_event()

func click(at : Vector2i) -> void:
	match at.x:
		Zone.CLOSE:
			close()
		Zone.CHANGE, Zone.ROD:
			if not rods.is_empty():
				fill_rods()
				rodPicker.open_menu()
				clear_tip()
		Zone.SLOT:
			select_slot(at.y)

func select_slot(target : int) -> void:
	if target != slot:
		slot = target
		parts.reset_scroll()
		refresh()

func choose_rod(value : Variant) -> void:
	var item : RodItem = inventory.items[value] as RodItem
	if item and item != rod:
		rod = item
		slot = 0
		parts.reset_scroll()
		refresh()
	rodPicker.close_menu()

func choose_part(value : Variant) -> void:
	set_part(slot, value as Tackle if value is Tackle else null)

func set_part(target : int, part : Tackle) -> void:
	if not rod or rod.tackle[target] == part:
		return
	if locked or not box.can_equip(rod, target, part, inventory):
		if target == slot:
			parts.flash(part)
		return
	rod.set_tackle(target, part)
	inventory.emit_changed()

func hover(at : Vector2i, force : bool = false) -> void:
	if not force and at.x == zone and at.y == index:
		return
	zone = at.x as Zone
	index = at.y
	clear_tip()
	match zone:
		Zone.CLOSE:
			set_tip("Close", ui.textColor, PackedStringArray(["T or Esc", ""]))
		Zone.CHANGE, Zone.ROD:
			set_tip("Change rod", ui.textColor, PackedStringArray(["%d rods" % rods.size(), ""]))
		Zone.SLOT:
			var part : Tackle = rod.tackle[index]
			if part:
				var lines : PackedStringArray = part.details()
				lines.append_array(["Required", ""] if rod.is_required(index) else ["Right-click", "remove"])
				set_tip(part.displayName, part.title_color(), lines, part.tag())
			else:
				set_tip("Empty %s slot" % Tackle.KIND_NAMES[rod.slots[index]].to_lower(), ui.textColor, PackedStringArray(["Click to pick a part", ""]))

func point_part(value : Variant) -> void:
	clear_tip()
	if not rod or value == null:
		return
	var part : Tackle = value as Tackle if value is Tackle else null
	if not part:
		set_tip("Empty", ui.textColor, PackedStringArray(["Take the part off", ""]))
		preview = trial(null)
	elif not box.knows(part):
		set_tip("???", ui.textColor, PackedStringArray(["Not found yet", ""]))
	else:
		var lines : PackedStringArray = part.details()
		lines.append_array(["Owned", "%d" % box.count(part), "Free", "%d" % box.free_count(part, inventory)])
		set_tip(part.displayName, part.title_color(), lines, part.tag())
		preview = trial(part)
	tipLeftOf = parts.home.x
	queue_redraw()

func point_rod(value : Variant) -> void:
	clear_tip()
	var item : RodItem = inventory.items[value] as RodItem if value != null else null
	if item:
		set_tip(item.displayName, item.title_color(), item.details(), item.tag())

func set_tip(title : String, color : Color, lines : PackedStringArray, subtitle : String = "") -> void:
	tipSub = subtitle
	tipTitle = title
	tipColor = color
	tipLines = lines
	tipSize = ui.tip_size(title, lines, subtitle)
	tipLayer.queue_redraw()

func clear_tip() -> void:
	tipTitle = ""
	tipLines = PackedStringArray()
	tipSize = Vector2.ZERO
	tipLeftOf = -1.0
	if not preview.is_empty():
		preview = []
		queue_redraw()
	if tipLayer:
		tipLayer.queue_redraw()

func trial(part : Tackle) -> Array:
	if not rod or rod.tackle[slot] == part:
		return []
	var trying : Array[Tackle] = rod.tackle.duplicate()
	trying[slot] = part
	return rod.stat_rows(trying)

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panelRect.position + Vector2(2.0, 2.0), panelRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panelRect)
	UiKit.box(self, skin.well, Rect2(statsRect.position - Vector2(2.0, 2.0), statsRect.size + Vector2(4.0, 3.0)))
	UiKit.box(self, skin.tabHover if zone == Zone.CLOSE else skin.tab, closeRect)
	draw_cross(closeRect.grow(-3.5), skin.text)
	var baseline : float = rodRect.position.y + roundf((ui.slotSize + font.get_ascent(ui.titleSize)) * 0.5)
	if not rod:
		draw_string(font, Vector2(rodRect.position.x, baseline), "No rods to customize", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, ui.dimColor)
		return
	draw_frame(rodRect, ui.hoverColor if zone == Zone.ROD else ui.selectedColor)
	ui.draw_icon(self, rod.icon, rodRect.get_center(), Color.WHITE, ui.outline_color(rod))
	var many : bool = rods.size() > 1
	draw_frame(changeRect, ui.hoverColor if zone == Zone.CHANGE else ui.frameColor)
	draw_string(font, Vector2(changeRect.position.x, roundf(changeRect.position.y + (changeRect.size.y + font.get_ascent(ui.statSize)) * 0.5)), "Change rod", HORIZONTAL_ALIGNMENT_CENTER, changeRect.size.x, ui.statSize, ui.textColor if many else ui.dimColor)
	var nameX : float = rodRect.end.x + 3.0
	var status : String = "In use" if locked else ""
	var statusWidth : float = font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
	draw_string(font, Vector2(nameX, baseline), rod.displayName, HORIZONTAL_ALIGNMENT_LEFT, changeRect.position.x - nameX - statusWidth - 4.0, ui.titleSize, ui.textColor)
	if locked:
		draw_string(font, Vector2(changeRect.position.x - 2.0 - statusWidth, baseline), status, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, worseColor)
	draw_ring()
	draw_stats(font)
	if rodPicker.shown:
		draw_rect(panelRect, shadeColor)

func draw_ring() -> void:
	draw_arc(center, radius, 0.0, TAU, 48, ringColor, 1.0)
	for i in slotRects.size():
		draw_line(center, slotRects[i].get_center(), Color(ringColor, ringColor.a * 0.5), 1.0)
	draw_scaled(rod.icon, center, rodScale, Color(1.0, 1.0, 1.0, 0.45 if locked else 1.0))
	for i in slotRects.size():
		var area : Rect2 = slotRects[i]
		draw_frame(area, ui.selectedColor if i == slot else (ui.hoverColor if zone == Zone.SLOT and index == i else ui.frameColor))
		var part : Tackle = rod.tackle[i]
		if part:
			draw_scaled(part.icon, area.get_center(), 1.0, part.icon_tint())
		elif rod.slots[i] < kindIcons.size():
			draw_scaled(kindIcons[rod.slots[i]], area.get_center(), 1.0, Color(1.0, 1.0, 1.0, 0.3))

func draw_stats(font : Font) -> void:
	if base.is_empty():
		return
	var values : PackedFloat32Array = base[0]
	var texts : PackedStringArray = base[1]
	var y : float = statsRect.position.y
	for i in values.size():
		var baseline : Vector2 = Vector2(statsRect.position.x, y + font.get_ascent(ui.statSize))
		var text : String = texts[i]
		var color : Color = ui.textColor
		if not preview.is_empty():
			var change : int = FishingRod.stat_change(i, values[i], preview[0][i])
			text = preview[1][i]
			color = betterColor if change > 0 else (worseColor if change < 0 else ui.textColor)
		draw_string(font, baseline, FishingRod.STAT_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_RIGHT, statsRect.size.x, ui.statSize, color)
		y += ui.statSize + 1.0

# Part tooltips open to the left of the list so the stat preview stays visible.
func draw_tip() -> void:
	if tipSize == Vector2.ZERO:
		return
	var pointer : Vector2 = get_local_mouse_position()
	if tipLeftOf >= 0.0:
		pointer = Vector2(tipLeftOf - tipSize.x - 7.0, pointer.y - 4.0)
	ui.paint_tip(tipLayer, pointer, tipTitle, tipColor, tipLines, tipSize, tipSub)

func draw_frame(area : Rect2, color : Color) -> void:
	draw_rect(area, color)
	draw_rect(area.grow(-1.0), Color(0.08, 0.18, 0.15))
	draw_rect(Rect2(area.position.x + 1.0, area.position.y + 1.0, area.size.x - 2.0, 1.0), Color(0.0, 0.0, 0.0, 0.25))

func draw_cross(area : Rect2, color : Color) -> void:
	draw_line(area.position, area.end, color, 1.0)
	draw_line(Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), color, 1.0)

func draw_scaled(icon : Texture2D, at : Vector2, amount : float, tint : Color) -> void:
	if icon:
		var drawn : Vector2 = (icon.get_size() * amount).round()
		draw_texture_rect(icon, Rect2((at - drawn * 0.5).round(), drawn), false, tint)
