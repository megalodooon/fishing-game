extends Control
class_name InventoryUI

# The hotbar, the backpack (a MenuPanel so it fades in) and the drag and
# tooltip layer above both. Everything is drawn here; the backpack and the
# overlay are plain canvases whose draw signals call back into this script.
# hotbarOnTop and uiScale are meant for the settings screen.

const NONE : int = -1

signal opened
# The hotbar moved or the UI changed size.
signal laid_out

#------------------------#
@export var player : Player
@export var font : Font
@export var hotbarOnTop : bool = false:
	set(value):
		hotbarOnTop = value
		layout()
@export_range(0.5, 2.0, 0.05, "or_greater") var uiScale : float = 1.0:
	set(value):
		uiScale = maxf(value, 0.1)
		fit()

@export_group("Icons")
@export var trashIcon : Texture2D
@export var catchIcon : Texture2D
@export var trashTime : float = 0.35

@export_group("Layout")
@export var slotSize : int = 12
@export var gap : int = 1
@export var margin : int = 2
@export var columns : int = 5
@export var iconScale : float = 0.5
@export var titleSize : int = 4
@export var statSize : int = 3
@export var tipPadding : int = 2

@export_group("Colors")
@export var slotColor : Color = Color(0.1, 0.16, 0.25, 0.9)
@export var frameColor : Color = Color(0.04, 0.07, 0.13, 1.0)
@export var panelColor : Color = Color(0.16, 0.24, 0.34, 0.95)
@export var hoverColor : Color = Color(0.55, 0.68, 0.82, 1.0)
@export var selectedColor : Color = Color(1.0, 0.9, 0.4, 1.0)
@export var textColor : Color = Color(0.94, 0.97, 1.0, 1.0)
@export var dimColor : Color = Color(0.58, 0.67, 0.78, 1.0)
@export var blockedColor : Color = Color(0.95, 0.38, 0.34, 1.0)
# Drawn one art pixel around every item icon. Items with a rarity use its
# color instead, mixed this far toward white.
@export var outlineColor : Color = Color.WHITE
@export_range(0.0, 1.0) var rarityWhiten : float = 0.35

var inventory : Inventory
var open : bool = false
var backpack : MenuPanel
var overlay : Control
var rects : Array[Rect2] = []
var hotbarRect : Rect2
var panelRect : Rect2
var hovered : int = NONE
var dragFrom : int = NONE
var mouse : Vector2
var shownSlot : int = NONE
var outlines : Dictionary = {}
var offsets : Dictionary = {}
var tipKey : Variant = null
var tipTitle : String = ""
var tipColor : Color = Color.WHITE
var tipLines : PackedStringArray = PackedStringArray()
var tipSize : Vector2 = Vector2.ZERO
var thrown : Item
var thrownAge : float = 0.0
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	backpack = MenuPanel.new()
	backpack.blocksMouse = false
	backpack.draw.connect(draw_backpack)
	add_child(backpack)
	overlay = Control.new()
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_overlay)
	add_child(overlay)
	if player:
		inventory = player.inventory
		inventory.changed.connect(refresh)
		inventory.needs_room.connect(show_backpack)
		inventory.trashed.connect(throw_away)
	set_anchors_preset(PRESET_TOP_LEFT)
	resized.connect(layout)
	get_viewport().size_changed.connect(fit)
	fit()

# The whole UI is drawn at uiScale, laid out on the screen shrunk by the same amount.
func fit() -> void:
	if not is_node_ready():
		return
	scale = Vector2.ONE * uiScale
	size = get_viewport_rect().size / uiScale
	layout()

func _process(delta : float) -> void:
	if player and player.heldSlot != shownSlot:
		shownSlot = player.heldSlot
		queue_redraw()
	if hovered != NONE and dragFrom == NONE and not rects[hovered].has_point(get_local_mouse_position()):
		hover(NONE)
	if thrown:
		thrownAge += delta
		if thrownAge >= trashTime:
			thrown = null
		backpack.queue_redraw()

func throw_away(item : Item) -> void:
	thrown = item
	thrownAge = 0.0

# A number key over an item in the open inventory swaps it into that hotbar
# slot instead of switching the held item.
func _input(event : InputEvent) -> void:
	if not open or hovered == NONE or dragFrom != NONE or not inventory.get_item(hovered):
		return
	var slot : int = player.slot_pressed(event)
	if slot < 0:
		return
	get_viewport().set_input_as_handled()
	if slot != hovered and can_drop(hovered, slot):
		inventory.move(hovered, slot)

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("backpack"):
		toggle()

func _has_point(point : Vector2) -> bool:
	return hotbarRect.has_point(point) or (open and panelRect.has_point(point))

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and dragFrom == NONE:
		hover(NONE)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		hover(slot_at(mouse))
		if dragFrom != NONE or hovered != NONE:
			overlay.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		var at : int = slot_at(mouse)
		if event.pressed:
			if inventory.get_item(at) and player.can_move_slot(at):
				dragFrom = at
		elif dragFrom != NONE:
			if at >= 0 and can_drop(dragFrom, at):
				inventory.move(dragFrom, at)
			dragFrom = NONE
		hover(at)
		redraw()
		accept_event()

func can_drop(from : int, to : int) -> bool:
	return inventory.can_move(from, to) and player.can_move_slot(from) and player.can_move_slot(to)

func toggle() -> void:
	open = not open
	if not open and dragFrom >= inventory.hotbarSize:
		dragFrom = NONE
	hover(slot_at(mouse))
	if open:
		backpack.open_menu()
		opened.emit()
	else:
		backpack.close_menu()
	redraw()

func close() -> void:
	if open:
		toggle()

func show_backpack() -> void:
	if not open:
		toggle()

func refresh() -> void:
	tipKey = null
	hover(slot_at(mouse))
	redraw()

func redraw() -> void:
	queue_redraw()
	backpack.queue_redraw()
	overlay.queue_redraw()

func hover(slot : int) -> void:
	hovered = slot
	var item : Item = inventory.get_item(slot) if inventory and slot >= 0 else null
	var key : Variant = slot
	if item:
		key = item
	if is_same(key, tipKey):
		return
	tipKey = key
	tipTitle = ""
	tipLines = PackedStringArray()
	tipColor = textColor
	if item:
		tipTitle = item.displayName
		tipColor = item.title_color()
		tipLines = item.details()
	elif inventory and slot == inventory.catchSlot:
		tipTitle = "Catch"
		tipLines = PackedStringArray(["Fish that didn't fit", ""])
	elif inventory and slot == inventory.trashSlot:
		tipTitle = "Trash"
		tipLines = PackedStringArray(["Drop items here to", "", "throw them away", ""])
	tipSize = tip_size(tipTitle, tipLines)
	redraw()

func tip_size(title : String, lines : PackedStringArray) -> Vector2:
	if title.is_empty() or not font:
		return Vector2.ZERO
	var width : float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, titleSize).x
	for i in range(0, lines.size() - 1, 2):
		var label : float = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, statSize).x
		var value : float = font.get_string_size(lines[i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, statSize).x
		width = maxf(width, label + (statSize * 2.0 if value > 0.0 else 0.0) + value)
	return Vector2(ceilf(width), titleSize + lines.size() / 2.0 * (statSize + 1.0)) + Vector2.ONE * tipPadding * 2.0

func layout() -> void:
	if not is_node_ready() or not inventory:
		return
	var screen : Vector2 = size
	var step : int = slotSize + gap
	var hotbarWidth : int = inventory.hotbarSize * step
	var hotbarX : int = floori((screen.x - hotbarWidth) * 0.5)
	var hotbarY : int = margin if hotbarOnTop else floori(screen.y) - margin - slotSize
	rects.resize(inventory.trashSlot + 1)
	for i in inventory.hotbarSize:
		rects[i] = Rect2(hotbarX + i * step, hotbarY, slotSize, slotSize)
	hotbarRect = Rect2(hotbarX, hotbarY, hotbarWidth - gap, slotSize).grow(1.0)
	var rows : int = maxi(ceili(inventory.backpackSize / float(columns)), 2)
	var inner : Vector2i = Vector2i((columns + 1) * step + gap * 2 - gap, rows * step - gap)
	var panelSize : Vector2i = inner + Vector2i.ONE * (gap + 2) * 2
	var panelX : int = floori((screen.x - panelSize.x) * 0.5)
	var panelY : int = hotbarY + slotSize + margin + 1 if hotbarOnTop else hotbarY - margin - 1 - panelSize.y
	panelRect = Rect2(panelX, panelY, panelSize.x, panelSize.y)
	var origin : Vector2 = panelRect.position + Vector2.ONE * (gap + 2)
	for i in inventory.backpackSize:
		rects[inventory.hotbarSize + i] = Rect2(origin + Vector2(i % columns, floori(i / float(columns))) * step, Vector2.ONE * slotSize)
	var sideX : float = origin.x + columns * step + gap * 2
	rects[inventory.catchSlot] = Rect2(sideX, origin.y, slotSize, slotSize)
	rects[inventory.trashSlot] = Rect2(sideX, origin.y + step, slotSize, slotSize)
	backpack.slide = Vector2(0.0, -4.0 if hotbarOnTop else 4.0)
	backpack.place(Rect2(Vector2.ZERO, size))
	overlay.size = size
	redraw()
	laid_out.emit()

func slot_at(point : Vector2) -> int:
	if not inventory:
		return NONE
	for i in inventory.hotbarSize:
		if rects[i].has_point(point):
			return i
	if open:
		for i in range(inventory.hotbarSize, rects.size()):
			if rects[i].has_point(point):
				return i
	return NONE

func _draw() -> void:
	if not inventory:
		return
	for i in inventory.hotbarSize:
		draw_slot(self, i)

func draw_backpack() -> void:
	if not inventory:
		return
	backpack.draw_rect(panelRect, frameColor)
	backpack.draw_rect(panelRect.grow(-1.0), panelColor)
	for i in range(inventory.hotbarSize, rects.size()):
		draw_slot(backpack, i)

func draw_overlay() -> void:
	if not inventory:
		return
	if dragFrom != NONE:
		var item : Item = inventory.get_item(dragFrom)
		var target : int = slot_at(mouse)
		if target >= 0 and target != dragFrom and not can_drop(dragFrom, target):
			draw_frame(overlay, rects[target], blockedColor)
		if item and item.icon:
			draw_icon(overlay, item.icon, mouse, Color.WHITE, outline_color(item))
	elif tipSize != Vector2.ZERO and hovered != NONE:
		paint_tip(overlay, mouse, tipTitle, tipColor, tipLines, tipSize)

func draw_slot(canvas : CanvasItem, slot : int) -> void:
	var area : Rect2 = rects[slot]
	var item : Item = inventory.get_item(slot)
	var color : Color = frameColor
	if slot == player.heldSlot:
		color = selectedColor
	elif slot == hovered:
		color = hoverColor
	draw_frame(canvas, area, color)
	if item and item.icon:
		draw_icon(canvas, item.icon, area.get_center(), Color(1.0, 1.0, 1.0, 0.35 if slot == dragFrom else 1.0), outline_color(item))
	elif slot == inventory.trashSlot and trashIcon:
		var t : float = clampf(thrownAge / trashTime, 0.0, 1.0) if thrown else 1.0
		var bump : float = sin(t * PI)
		canvas.draw_texture(trashIcon, (area.get_center() - trashIcon.get_size() * 0.5).floor() - Vector2(0.0, roundf(bump * 1.5)), Color(1.0, 1.0, 1.0, 0.35 + bump * 0.4))
		if thrown and thrown.icon and t < 1.0:
			draw_icon(canvas, thrown.icon, area.get_center() + Vector2(0.0, t * t * 4.0), Color(1.0, 1.0, 1.0, 1.0 - t * t), outline_color(thrown), fit_scale(thrown.icon) * (1.0 - t * 0.7))
	elif slot == inventory.catchSlot and catchIcon:
		canvas.draw_texture(catchIcon, (area.get_center() - catchIcon.get_size() * 0.5).floor(), Color(1.0, 1.0, 1.0, 0.35))

func draw_frame(canvas : CanvasItem, area : Rect2, color : Color) -> void:
	canvas.draw_rect(area, color)
	canvas.draw_rect(area.grow(-1.0), slotColor)

func outline_color(item : Item) -> Color:
	return item.rarity.color.lerp(Color.WHITE, rarityWhiten) if item and item.rarity else outlineColor

# Centers the icon's visible pixels, not its canvas, snapped to its own pixel
# grid. Icons too big for a slot at iconScale (like long fish) shrink to fit.
func draw_icon(canvas : CanvasItem, icon : Texture2D, center : Vector2, tint : Color, outline : Color = outlineColor, amount : float = 0.0) -> void:
	var drawn : float = amount if amount > 0.0 else fit_scale(icon)
	var shown : Vector2 = icon.get_size() + Vector2(2.0, 2.0)
	var corner : Vector2 = center - (shown * 0.5 + icon_offset(icon)) * drawn
	var area : Rect2 = Rect2((corner / drawn).round() * drawn, shown * drawn)
	var mask : Texture2D = outline_of(icon)
	if mask and outline.a > 0.0:
		canvas.draw_texture_rect(mask, area, false, outline * Color(1.0, 1.0, 1.0, tint.a))
	canvas.draw_texture_rect(icon, area.grow(-drawn), false, tint)

func fit_scale(icon : Texture2D) -> float:
	return minf(iconScale, (slotSize - 2.0) / (maxf(icon.get_width(), icon.get_height()) + 2.0))

# How far the middle of the icon's visible pixels is from the middle of its canvas.
func icon_offset(icon : Texture2D) -> Vector2:
	outline_of(icon)
	return offsets.get(icon, Vector2.ZERO)

# A white one pixel outline around the icon's opaque pixels, one pixel bigger
# than the icon on every side. Made once per icon and tinted when drawn.
func outline_of(icon : Texture2D) -> Texture2D:
	if outlines.has(icon):
		return outlines[icon]
	var source : Image = icon.get_image()
	if not source:
		outlines[icon] = null
		return null
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var width : int = source.get_width()
	var height : int = source.get_height()
	var image : Image = Image.create_empty(width + 2, height + 2, false, Image.FORMAT_RGBA8)
	var solid : Callable = func(x : int, y : int) -> bool: return x >= 0 and y >= 0 and x < width and y < height and source.get_pixel(x, y).a > 0.5
	for y in height + 2:
		for x in width + 2:
			if not solid.call(x - 1, y - 1) and (solid.call(x - 2, y - 1) or solid.call(x, y - 1) or solid.call(x - 1, y - 2) or solid.call(x - 1, y)):
				image.set_pixel(x, y, Color.WHITE)
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	outlines[icon] = texture
	offsets[icon] = Rect2(source.get_used_rect()).get_center() - Vector2(width, height) * 0.5
	return texture

# Breaks the text into lines that fit the width, at spaces and line breaks.
func wrap_lines(text : String, width : float, fontSize : int) -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	for part in text.split("\n"):
		var line : String = ""
		for word in part.split(" ", false):
			var longer : String = word if line.is_empty() else line + " " + word
			if line.is_empty() or font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x <= width:
				line = longer
			else:
				lines.append(line)
				line = word
		lines.append(line)
	return lines

# Draws a tooltip next to the pointer onto any canvas item laid out like this one.
func paint_tip(canvas : CanvasItem, pointer : Vector2, title : String, color : Color, lines : PackedStringArray, box : Vector2) -> void:
	var at : Vector2 = pointer + Vector2(4.0, 4.0)
	if at.x + box.x > size.x:
		at.x = pointer.x - 2.0 - box.x
	if at.y + box.y > size.y:
		at.y = pointer.y - 2.0 - box.y
	at = at.clamp(Vector2.ZERO, (size - box).max(Vector2.ZERO)).round()
	var area : Rect2 = Rect2(at, box)
	canvas.draw_rect(area, frameColor)
	canvas.draw_rect(area.grow(-1.0), Color(slotColor, 0.97))
	var pen : Vector2 = at + Vector2(tipPadding, tipPadding)
	canvas.draw_string(font, pen + Vector2(0.0, font.get_ascent(titleSize)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, titleSize, color)
	pen.y += titleSize + 1.0
	var inner : float = box.x - tipPadding * 2.0
	for i in range(0, lines.size() - 1, 2):
		var baseline : Vector2 = pen + Vector2(0.0, font.get_ascent(statSize))
		canvas.draw_string(font, baseline, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, statSize, dimColor)
		canvas.draw_string(font, baseline, lines[i + 1], HORIZONTAL_ALIGNMENT_RIGHT, inner, statSize, textColor)
		pen.y += statSize + 1.0
