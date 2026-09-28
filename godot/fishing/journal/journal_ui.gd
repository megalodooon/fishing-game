extends MenuPanel
class_name JournalUI

# An open book. The left page is a grid of one page's fish, the right page
# shows the fish clicked on, or the page's progress when none is. Page 0
# holds every fish, the others one ocean each, and the journal always opens
# on the ocean the boat is in. Fish not caught yet are black silhouettes.
# Icons bigger than a cell (like 32x16 fish) span more cells.

enum Zone { NONE, CELL, PREV, NEXT, CLOSE }

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var tacklebox : TackleboxUI

@export_group("Text")
@export var allTitle : String = "All Fish"
@export_multiline var allDescription : String = "Every fish from every ocean."
@export var hiddenText : String = "Not discovered yet"
@export var completeText : String = "Complete!"

@export_group("Layout")
@export var maxSize : Vector2 = Vector2(188, 104)
@export var edge : int = 2
@export var cover : int = 2
@export var padding : int = 3
@export var spine : int = 3
@export var buttonSize : int = 7
# Icon pixels per grid cell; bigger icons take up more cells.
@export var cellArt : int = 16
@export var cellGap : int = 1
@export var columns : int = 5
@export var detailScale : float = 2.0
@export var flipTime : float = 0.16
@export var flipSlide : float = 4.0

@export_group("Colors")
@export var coverColor : Color = Color(0.54, 0.12, 0.17)
@export var coverEdgeColor : Color = Color(0.22, 0.12, 0.13)
@export var pageColor : Color = Color(0.16, 0.24, 0.34, 1.0)
@export var cellColor : Color = Color(0.1, 0.16, 0.25, 1.0)
@export var silhouetteColor : Color = Color.BLACK
# Outline of fish not caught yet. Clear by default, so they're plain silhouettes.
@export var hiddenOutline : Color = Color(0.0, 0.0, 0.0, 0.0)
@export var newColor : Color = Color(1.0, 0.9, 0.4)
@export var barColor : Color = Color(0.56, 0.93, 0.44)

var journal : Journal
var pageIndex : int = 0
var list : Array[FishData] = []
# The grid cell each fish in the list sits in, and how many cells it spans.
var cells : Array[Rect2i] = []
var rows : int = 0
var selected : FishData
var zone : Zone = Zone.NONE
var hoveredCell : int = -1
var scroll : float = 0.0
var mouse : Vector2 = Vector2.ZERO
var sheet : Control
var grid : Control
var detail : Control
var tipLayer : Control
var sheetMotion : Tween
var detailMotion : Tween
var bookRect : Rect2
var leftRect : Rect2
var rightRect : Rect2
var gridRect : Rect2
var detailRect : Rect2
var prevRect : Rect2
var nextRect : Rect2
var closeRect : Rect2
var tipTitle : String = ""
var tipColor : Color = Color.WHITE
var tipLines : PackedStringArray = PackedStringArray()
var tipSize : Vector2 = Vector2.ZERO
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	journal = player.journal
	sheet = canvas(self, draw_sheet)
	grid = canvas(sheet, draw_grid)
	grid.clip_contents = true
	detail = canvas(sheet, draw_detail)
	tipLayer = canvas(self, draw_tip)
	journal.changed.connect(refresh)
	ui.opened.connect(close)
	ui.laid_out.connect(fit)
	if tacklebox:
		tacklebox.opened.connect(close)
	fit()

func canvas(parent : Control, drawer : Callable) -> Control:
	var child : Control = Control.new()
	child.mouse_filter = MOUSE_FILTER_IGNORE
	child.draw.connect(drawer)
	parent.add_child(child)
	return child

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	layout()

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle()
	elif shown and event.is_action_pressed("ui_cancel"):
		close()
	elif shown and event.is_action_pressed("ui_left"):
		turn(-1)
	elif shown and event.is_action_pressed("ui_right"):
		turn(1)

func _has_point(point : Vector2) -> bool:
	return shown and bookRect.has_point(point)

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover(Zone.NONE, -1)

func toggle() -> void:
	if shown:
		close()
	else:
		ui.close()
		if tacklebox:
			tacklebox.close()
		var biome : Biome = Ocean.current_biome(get_tree())
		show_page(journal.biomes.find(biome) + 1 if biome else 0, 0)
		open_menu()

func close() -> void:
	if shown:
		close_menu()
		clear_tip()

func page_count() -> int:
	return journal.biomes.size() + 1

func page_biome() -> Biome:
	return journal.biomes[pageIndex - 1] if pageIndex > 0 and pageIndex <= journal.biomes.size() else null

func turn(direction : int) -> void:
	show_page(wrapi(pageIndex + direction, 0, page_count()), direction)

# Turning slides the new page in from the side it comes from.
func show_page(index : int, direction : int) -> void:
	pageIndex = clampi(index, 0, page_count() - 1)
	var biome : Biome = page_biome()
	list.assign(biome.fish.filter(func(data : FishData) -> bool: return data != null) if biome else journal.all_fish())
	selected = null
	scroll = 0.0
	pack()
	if direction != 0:
		sheetMotion = slide_in(sheetMotion, sheet, Vector2.ZERO, Vector2(flipSlide * direction, 0.0))
	refresh()

# First-fit packing in list order: a fish that doesn't fit at the end of a
# row goes to the next one, and the gap it leaves takes the next fish that fits.
func pack() -> void:
	cells.clear()
	rows = 0
	var taken : Dictionary[Vector2i, bool] = {}
	for data in list:
		var art : Vector2 = data.icon.get_size() if data.icon else Vector2.ONE
		var span : Vector2i = Vector2i(clampi(ceili(art.x / cellArt), 1, columns), maxi(ceili(art.y / cellArt), 1))
		var at : Vector2i = Vector2i.ZERO
		while not fits(taken, at, span):
			at.x += 1
			if at.x + span.x > columns:
				at = Vector2i(0, at.y + 1)
		for y in span.y:
			for x in span.x:
				taken[at + Vector2i(x, y)] = true
		cells.append(Rect2i(at, span))
		rows = maxi(rows, at.y + span.y)

func fits(taken : Dictionary[Vector2i, bool], at : Vector2i, span : Vector2i) -> bool:
	for y in span.y:
		for x in span.x:
			if taken.has(at + Vector2i(x, y)):
				return false
	return true

func step() -> int:
	return cellArt + 2 + cellGap

func max_scroll() -> float:
	return maxf(rows * step() - cellGap - gridRect.size.y, 0.0)

func cell_rect(index : int) -> Rect2:
	var cell : Rect2i = cells[index]
	return Rect2(Vector2(cell.position * step()) - Vector2(0.0, scroll), Vector2(cell.size * step()) - Vector2.ONE * cellGap)

func layout() -> void:
	var book : Vector2 = Vector2(minf(size.x - edge * 2.0, maxSize.x), minf(size.y - edge * 2.0, maxSize.y)).floor()
	bookRect = Rect2(((size - book) * 0.5).floor(), book)
	var inner : Rect2 = bookRect.grow(-cover)
	var gridWidth : float = columns * step() - cellGap
	leftRect = Rect2(inner.position, Vector2(gridWidth + padding * 2.0, inner.size.y))
	rightRect = Rect2(leftRect.end.x + spine, inner.position.y, inner.end.x - leftRect.end.x - spine, inner.size.y)
	var button : Vector2 = Vector2.ONE * buttonSize
	prevRect = Rect2(leftRect.position + Vector2.ONE * padding, button)
	nextRect = Rect2(Vector2(leftRect.end.x - padding - buttonSize, prevRect.position.y), button)
	closeRect = Rect2(Vector2(rightRect.end.x - padding - buttonSize, prevRect.position.y), button)
	var gridTop : float = prevRect.end.y + 3.0
	gridRect = Rect2(leftRect.position.x + padding, gridTop, gridWidth, leftRect.end.y - padding - gridTop)
	detailRect = Rect2(rightRect.position + Vector2.ONE * padding, rightRect.size - Vector2.ONE * padding * 2.0)
	sheet.size = size
	grid.position = gridRect.position - Vector2.ONE
	grid.size = gridRect.size + Vector2.ONE * 2.0
	if not detailMotion or not detailMotion.is_running():
		detail.position = detailRect.position
	detail.size = detailRect.size
	tipLayer.size = size
	scroll = clampf(scroll, 0.0, max_scroll())
	queue_redraw()
	refresh()

func refresh() -> void:
	if not shown and not visible:
		return
	if selected and not list.has(selected):
		selected = null
	update_tip()
	queue_redraw()
	sheet.queue_redraw()
	grid.queue_redraw()
	detail.queue_redraw()

# Fades a part of the book in while it slides home. Returns the new motion,
# which replaces the one passed in.
func slide_in(running : Tween, target : Control, rest : Vector2, from : Vector2) -> Tween:
	if running:
		running.kill()
	target.modulate.a = 0.0
	target.position = rest + from
	var tween : Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, flipTime)
	tween.tween_property(target, "position", rest, flipTime)
	return tween

func zone_at(point : Vector2) -> Vector2i:
	if not shown:
		return Vector2i(Zone.NONE, -1)
	if closeRect.has_point(point):
		return Vector2i(Zone.CLOSE, 0)
	if prevRect.has_point(point):
		return Vector2i(Zone.PREV, 0)
	if nextRect.has_point(point):
		return Vector2i(Zone.NEXT, 0)
	if gridRect.has_point(point):
		var local : Vector2 = point - gridRect.position
		for i in cells.size():
			if cell_rect(i).has_point(local):
				return Vector2i(Zone.CELL, i)
	return Vector2i(Zone.NONE, -1)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouse:
		mouse = event.position
	if event is InputEventMouseMotion:
		var at : Vector2i = zone_at(event.position)
		hover(at.x as Zone, at.y)
		if tipSize != Vector2.ZERO:
			tipLayer.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var at : Vector2i = zone_at(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				click(at.x as Zone, at.y)
			MOUSE_BUTTON_RIGHT:
				select(null)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if gridRect.has_point(event.position) and max_scroll() > 0.0:
					scroll = clampf(scroll + step() * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 0.0, max_scroll())
					hover_at(event.position)
					refresh()
		accept_event()

func click(at : Zone, index : int) -> void:
	match at:
		Zone.CLOSE:
			close()
		Zone.PREV:
			turn(-1)
		Zone.NEXT:
			turn(1)
		Zone.CELL:
			select(null if list[index] == selected else list[index])
		_:
			if gridRect.has_point(mouse):
				select(null)

func select(data : FishData) -> void:
	if data == selected:
		return
	selected = data
	if data:
		journal.see(data)
	detailMotion = slide_in(detailMotion, detail, detailRect.position, Vector2(0.0, 2.0))
	refresh()

func hover_at(point : Vector2) -> void:
	var at : Vector2i = zone_at(point)
	hover(at.x as Zone, at.y, true)

func hover(at : Zone, index : int, force : bool = false) -> void:
	if not force and at == zone and index == hoveredCell:
		return
	zone = at
	hoveredCell = index if at == Zone.CELL else -1
	update_tip()
	if hoveredCell >= 0 and journal.is_found(list[hoveredCell]):
		journal.see(list[hoveredCell])
	grid.queue_redraw()
	queue_redraw()

func update_tip() -> void:
	clear_tip()
	match zone:
		Zone.CLOSE:
			set_tip("Close", ui.textColor, PackedStringArray(["J or Esc", ""]))
		Zone.PREV, Zone.NEXT:
			var target : int = wrapi(pageIndex + (-1 if zone == Zone.PREV else 1), 0, page_count())
			var biome : Biome = journal.biomes[target - 1] if target > 0 else null
			set_tip(biome.displayName if biome else allTitle, ui.textColor, PackedStringArray(["Arrow keys", ""]))
		Zone.CELL:
			if hoveredCell >= 0 and hoveredCell < list.size():
				var data : FishData = list[hoveredCell]
				if journal.is_found(data):
					set_tip(data.displayName, rarity_color(data), PackedStringArray())
				else:
					set_tip(hiddenText, ui.dimColor, PackedStringArray())

func set_tip(title : String, color : Color, lines : PackedStringArray) -> void:
	tipTitle = title
	tipColor = color
	tipLines = lines
	tipSize = ui.tip_size(title, lines)
	tipLayer.queue_redraw()

func clear_tip() -> void:
	tipTitle = ""
	tipLines = PackedStringArray()
	tipSize = Vector2.ZERO
	if tipLayer:
		tipLayer.queue_redraw()

func rarity_color(data : FishData) -> Color:
	return data.rarity.color if data.rarity else ui.textColor

func _draw() -> void:
	draw_rect(bookRect, coverEdgeColor)
	draw_rect(bookRect.grow(-1.0), coverColor)
	draw_rect(leftRect, pageColor)
	draw_rect(rightRect, pageColor)
	var middle : float = floorf(leftRect.end.x + spine * 0.5)
	draw_rect(Rect2(middle, bookRect.position.y + 1.0, 1.0, bookRect.size.y - 2.0), coverEdgeColor)
	draw_button(prevRect, Zone.PREV, -1.0)
	draw_button(nextRect, Zone.NEXT, 1.0)
	draw_frame(closeRect, ui.hoverColor if zone == Zone.CLOSE else ui.frameColor)
	var cross : Rect2 = closeRect.grow(-2.5)
	draw_line(cross.position, cross.end, ui.textColor, 1.0)
	draw_line(Vector2(cross.end.x, cross.position.y), Vector2(cross.position.x, cross.end.y), ui.textColor, 1.0)

func draw_button(area : Rect2, which : Zone, direction : float) -> void:
	draw_frame(area, ui.hoverColor if zone == which else ui.frameColor)
	var tip : Vector2 = area.get_center() + Vector2(direction * 1.5, 0.0)
	var back : float = tip.x - direction * 3.0
	draw_colored_polygon(PackedVector2Array([tip, Vector2(back, tip.y - 2.0), Vector2(back, tip.y + 2.0)]), ui.textColor)

func draw_frame(area : Rect2, color : Color) -> void:
	draw_rect(area, color)
	draw_rect(area.grow(-1.0), ui.slotColor)

# The page title and progress above the grid, and the scroll bar next to it.
func draw_sheet() -> void:
	var font : Font = ui.font
	var biome : Biome = page_biome()
	var title : String = biome.displayName if biome else allTitle
	var count : String = "%d/%d" % [journal.found_in(list), list.size()]
	var left : float = prevRect.end.x + 2.0
	var right : float = nextRect.position.x - 2.0
	var baseline : float = roundf(prevRect.position.y + (buttonSize + font.get_ascent(ui.titleSize)) * 0.5)
	var countWidth : float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
	sheet.draw_string(font, Vector2(left, baseline), title, HORIZONTAL_ALIGNMENT_LEFT, right - left - countWidth - 2.0, ui.titleSize, ui.textColor)
	sheet.draw_string(font, Vector2(right - countWidth, baseline), count, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
	if selected:
		sheet.draw_string(font, Vector2(detailRect.position.x, baseline), "No. %02d" % (list.find(selected) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
	var most : float = max_scroll()
	if most > 0.0:
		var track : Rect2 = Rect2(gridRect.end.x + 1.0, gridRect.position.y, 1.0, gridRect.size.y)
		var length : float = maxf(track.size.y * track.size.y / (track.size.y + most), 4.0)
		sheet.draw_rect(track, ui.slotColor)
		sheet.draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - length) * scroll / most, 1.0, length), ui.hoverColor)

func draw_grid() -> void:
	var origin : Vector2 = Vector2.ONE
	for i in cells.size():
		var area : Rect2 = cell_rect(i)
		area.position += origin
		if area.end.y < 0.0 or area.position.y > grid.size.y:
			continue
		var data : FishData = list[i]
		if data == selected or i == hoveredCell:
			grid.draw_rect(area.grow(1.0), ui.selectedColor if data == selected else ui.hoverColor)
		grid.draw_rect(area, cellColor)
		if not data.icon:
			continue
		if journal.is_found(data):
			ui.draw_icon(grid, data.icon, area.get_center(), Color.WHITE, rarity_color(data), 1.0)
			if journal.unseen.has(data):
				grid.draw_rect(Rect2(area.end.x - 3.0, area.position.y + 1.0, 2.0, 2.0), newColor)
		else:
			ui.draw_icon(grid, data.icon, area.get_center(), silhouetteColor, hiddenOutline, 1.0)

func draw_detail() -> void:
	if selected:
		draw_fish_page(selected)
	else:
		draw_progress()

func draw_fish_page(data : FishData) -> void:
	var font : Font = ui.font
	var width : float = detailRect.size.x
	var found : bool = journal.is_found(data)
	var y : float = buttonSize + 2.0
	if data.icon:
		var box : float = (data.icon.get_height() + 2.0) * detailScale
		ui.draw_icon(detail, data.icon, Vector2(width * 0.5, y + box * 0.5), Color.WHITE if found else silhouetteColor, rarity_color(data) if found else hiddenOutline, detailScale)
		y += box + 2.0
	y = centered_text(data.displayName if found else "???", y, ui.titleSize, rarity_color(data) if found else ui.textColor)
	if data.rarity:
		y = centered_text(data.rarity.displayName, y, ui.statSize, rarity_color(data))
	y += 2.0
	var text : String = data.description if found else hiddenText
	if not text.is_empty():
		y = paragraph(text, y, ui.dimColor) + 2.0
	var stats : PackedStringArray = PackedStringArray()
	if found:
		stats.append_array(["Caught", "%d" % journal.count(data), "Best", "%.2fkg" % journal.best(data), "Size", data.weight_range_text()])
	var places : PackedStringArray = journal.biome_names(data)
	if not places.is_empty():
		stats.append_array(["Where", places[0] + (" +%d" % (places.size() - 1) if places.size() > 1 else "")])
	stats.append_array(["When", data.hours_text()])
	for i in range(0, stats.size() - 1, 2):
		var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
		detail.draw_string(font, baseline, stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
		detail.draw_string(font, baseline, stats[i + 1], HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, ui.textColor)
		y += ui.statSize + 1.0

# How much of the page has been found, overall and per rarity.
func draw_progress() -> void:
	var font : Font = ui.font
	var width : float = detailRect.size.x
	var biome : Biome = page_biome()
	var found : int = journal.found_in(list)
	var y : float = buttonSize + 4.0
	y = centered_text("Discovered", y, ui.statSize, ui.dimColor)
	y = centered_text("%d/%d" % [found, list.size()], y + 1.0, ui.titleSize, ui.textColor) + 1.0
	detail.draw_rect(Rect2(0.0, y, width, 3.0), ui.frameColor)
	if not list.is_empty():
		detail.draw_rect(Rect2(0.0, y, roundf(width * found / list.size()), 3.0), barColor)
	y += 6.0
	if found == list.size() and not list.is_empty():
		y = centered_text(completeText, y, ui.statSize, ui.selectedColor) + 2.0
	var rarities : Array[Rarity] = []
	for data in list:
		if data.rarity and not rarities.has(data.rarity):
			rarities.append(data.rarity)
	for rarity in rarities:
		var ofRarity : Array[FishData] = []
		ofRarity.assign(list.filter(func(data : FishData) -> bool: return data.rarity == rarity))
		var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
		detail.draw_string(font, baseline, rarity.displayName, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, rarity.color)
		detail.draw_string(font, baseline, "%d/%d" % [journal.found_in(ofRarity), ofRarity.size()], HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, ui.textColor)
		y += ui.statSize + 1.0
	var text : String = biome.description if biome else allDescription
	if not text.is_empty():
		paragraph(text, y + 3.0, ui.dimColor)

func centered_text(text : String, y : float, fontSize : int, color : Color) -> float:
	detail.draw_string(ui.font, Vector2(0.0, y + ui.font.get_ascent(fontSize)), text, HORIZONTAL_ALIGNMENT_CENTER, detailRect.size.x, fontSize, color)
	return y + fontSize + 1.0

func paragraph(text : String, y : float, color : Color) -> float:
	for line in ui.wrap_lines(text, detailRect.size.x, ui.statSize):
		y = centered_text(line, y, ui.statSize, color)
	return y

func draw_tip() -> void:
	if tipSize != Vector2.ZERO:
		ui.paint_tip(tipLayer, mouse, tipTitle, tipColor, tipLines, tipSize)
