extends MenuPanel
class_name JournalUI

# A leather-bound fishing journal. The contents page lists every fishing
# ground by region with how much of it is found; clicking one opens its page.
# Colored bookmarks down the book's edge jump straight to a region (the top
# one back to the contents). On a ground's page the left side is a grid of
# its fish, the right side the fish clicked on, or the page's progress when
# none is. Fish not caught there yet are ink silhouettes. Grounds where sea
# creatures turn up get two tabs over the grid, Fish and Sea creatures; the
# creature side shows each one (silhouettes until beaten), when it bites and
# what it drops. The right page scrolls with the wheel when there's more on it
# than fits. The journal opens on the ground the player is at.

enum Zone { NONE, CELL, PREV, NEXT, TITLE, MARK, ENTRY, TAB }
enum Mode { CONTENTS, PAGE }

# Bookmark order and colors. A biome's region picks its bookmark; unknown
# regions share the last one.
const REGIONS : Array = [
	["Home Waters", Color(0.36, 0.7, 0.36)],
	["Sunny Seas", Color(0.2, 0.72, 0.8)],
	["Far North", Color(0.72, 0.86, 0.98)],
	["Fire Isles", Color(0.95, 0.45, 0.2)],
	["Storm Belt", Color(0.55, 0.45, 0.9)],
	["The Deep", Color(0.16, 0.28, 0.6)],
	["Festivals", Color(0.95, 0.3, 0.55)],
]
const CONTENTS_COLOR : Color = Color(0.95, 0.78, 0.3)

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var tacklebox : TackleboxUI
@export var skin : MenuSkin

@export_group("Text")
@export var allTitle : String = "All Fish"
@export_multiline var allDescription : String = "Every fish from every fishing ground."
@export var hiddenText : String = "Not discovered yet"
@export var completeText : String = "Complete!"

@export_group("Layout")
@export var maxSize : Vector2 = Vector2(180, 104)
@export var edge : int = 2
@export var cover : int = 3
@export var padding : int = 3
@export var spine : int = 3
@export var buttonSize : int = 7
# Icon pixels per grid cell; bigger icons take up more cells.
@export var cellArt : int = 16
@export var cellGap : int = 1
@export var columns : int = 4
@export var detailScale : float = 2.0
@export var flipTime : float = 0.16
@export var flipSlide : float = 4.0
@export var markWidth : float = 6.0
@export var markHeight : float = 9.0

@export_group("Colors")
@export var cellColor : Color = Color(0.85, 0.77, 0.6, 1.0)
@export var cellEdge : Color = Color(0.72, 0.62, 0.45, 1.0)
@export var silhouetteColor : Color = Color(0.36, 0.26, 0.17, 0.9)
# Outline of fish not caught yet. Clear by default, so they're plain silhouettes.
@export var hiddenOutline : Color = Color(0.0, 0.0, 0.0, 0.0)
@export var newColor : Color = Color(0.9, 0.3, 0.2)
@export var barColor : Color = Color(0.3, 0.62, 0.3)

var journal : Journal
var mode : Mode = Mode.CONTENTS
var pageIndex : int = 0
var list : Array[FishData] = []
# The grid cell each fish in the list sits in, and how many cells it spans.
var cells : Array[Rect2i] = []
var rows : int = 0
var selected : FishData
var zone : Zone = Zone.NONE
var hoveredIndex : int = -1
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
var titleRect : Rect2
# The bookmarks: the contents, then one per region that has pages.
var marks : Array[Array] = []
var markRects : Array[Rect2] = []
# The contents rows: [kind, page index or region, rect]. kind is "all",
# "region" or "page".
var entries : Array[Array] = []
var tipTitle : String = ""
var tipColor : Color = Color.WHITE
var tipLines : PackedStringArray = PackedStringArray()
var tipSize : Vector2 = Vector2.ZERO
var time : float = 0.0
# The Sea creatures tab of a page, its creatures and the one clicked on.
var creatureTab : bool = false
var creatureList : Array[SeaCreature] = []
var pickedCreature : SeaCreature
var tabRects : Array[Rect2] = []
# How far the right page is scrolled, and how tall its content was last drawn.
var detailScroll : float = 0.0
var detailHeight : float = 0.0
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/journal.tres") as MenuSkin
	journal = player.journal
	sheet = canvas(self, draw_sheet)
	grid = canvas(sheet, draw_grid)
	grid.clip_contents = true
	detail = canvas(sheet, draw_detail)
	detail.clip_contents = true
	tipLayer = canvas(self, draw_tip)
	journal.changed.connect(refresh)
	ui.opened.connect(close)
	ui.laid_out.connect(fit)
	if tacklebox:
		tacklebox.opened.connect(close)
	set_process(false)
	build_marks()
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

func hub_open() -> void:
	if not shown:
		toggle()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func hub_news() -> bool:
	return not journal.unseen.is_empty()

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if mode == Mode.PAGE:
			show_contents()
		else:
			close()
	elif event.is_action_pressed("ui_left"):
		turn(-1)
	elif event.is_action_pressed("ui_right"):
		turn(1)

func _has_point(point : Vector2) -> bool:
	if not shown:
		return false
	if bookRect.has_point(point):
		return true
	for area in markRects:
		if area.has_point(point):
			return true
	return false

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
		var here : Biome = Ocean.current_biome(get_tree())
		var biome : Biome = here.journal_page() if here else null
		if biome and journal.biomes.has(biome):
			show_page(journal.biomes.find(biome) + 1, 0)
		else:
			show_contents()
		open_menu()
		set_process(true)

func close() -> void:
	if shown:
		close_menu()
		clear_tip()
		set_process(false)

func page_count() -> int:
	return journal.biomes.size() + 1

func page_biome(index : int = pageIndex) -> Biome:
	return journal.biomes[index - 1] if index > 0 and index <= journal.biomes.size() else null

static func region_of(biome : Biome) -> int:
	for i in REGIONS.size():
		if REGIONS[i][0] == biome.region:
			return i
	return REGIONS.size() - 1

func region_color(biome : Biome) -> Color:
	return REGIONS[region_of(biome)][1] if biome else CONTENTS_COLOR

# The bookmarks: the contents first, then every region with pages in it.
func build_marks() -> void:
	marks = [["Contents", CONTENTS_COLOR, -1]]
	for i in REGIONS.size():
		for biome in journal.biomes:
			if region_of(biome) == i:
				marks.append([REGIONS[i][0], REGIONS[i][1], i])
				break

func turn(direction : int) -> void:
	if mode == Mode.CONTENTS:
		show_page(0 if direction > 0 else page_count() - 1, direction)
	else:
		show_page(wrapi(pageIndex + direction, 0, page_count()), direction)

func show_contents() -> void:
	mode = Mode.CONTENTS
	selected = null
	sheetMotion = slide_in(sheetMotion, sheet, Vector2.ZERO, Vector2(-flipSlide, 0.0))
	layout()

# Turning slides the new page in from the side it comes from.
func show_page(index : int, direction : int) -> void:
	mode = Mode.PAGE
	pageIndex = clampi(index, 0, page_count() - 1)
	var biome : Biome = page_biome()
	list.assign(biome.fish.filter(func(data : FishData) -> bool: return data != null) if biome else journal.all_fish())
	creatureList.assign(biome.creatures.filter(func(c : SeaCreature) -> bool: return c != null) if biome else [])
	creatureTab = false
	pickedCreature = null
	selected = null
	scroll = 0.0
	detailScroll = 0.0
	pack()
	sheetMotion = slide_in(sheetMotion, sheet, Vector2.ZERO, Vector2(flipSlide * (direction if direction != 0 else 1), 0.0))
	layout()

# The first page of a region.
func show_region(region : int) -> void:
	for i in journal.biomes.size():
		if region_of(journal.biomes[i]) == region:
			show_page(i + 1, 1)
			return

# First-fit packing in list order: a fish that doesn't fit at the end of a
# row goes to the next one, and the gap it leaves takes the next fish that fits.
func pack() -> void:
	cells.clear()
	rows = 0
	var taken : Dictionary[Vector2i, bool] = {}
	for data in shown_things():
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

# What the grid shows: the page's fish, or its sea creatures.
func shown_things() -> Array:
	return creatureList if creatureTab else list

func has_tabs() -> bool:
	return mode == Mode.PAGE and not creatureList.is_empty()

func beaten(creature : SeaCreature) -> bool:
	return player.progress.bestiary.has(creature)

func show_tab(creatures : bool) -> void:
	if creatures == creatureTab:
		return
	creatureTab = creatures
	selected = null
	pickedCreature = null
	scroll = 0.0
	detailScroll = 0.0
	pack()
	layout()

func fits(taken : Dictionary[Vector2i, bool], at : Vector2i, span : Vector2i) -> bool:
	for y in span.y:
		for x in span.x:
			if taken.has(at + Vector2i(x, y)):
				return false
	return true

func step() -> float:
	return cellArt + 2.0 + cellGap

func max_scroll() -> float:
	return maxf(rows * step() - cellGap - gridRect.size.y, 0.0)

func cell_rect(index : int) -> Rect2:
	var cell : Rect2i = cells[index]
	return Rect2((Vector2(cell.position) * step() - Vector2(0.0, scroll)).round(), (Vector2(cell.size) * step() - Vector2.ONE * cellGap).round())

func layout() -> void:
	var top : float = MenuHub.top_of(get_tree(), edge) if is_inside_tree() else float(edge)
	var book : Vector2 = Vector2(minf(size.x - edge * 2.0 - markWidth - 2.0, maxSize.x), minf(size.y - top - edge, maxSize.y)).floor()
	bookRect = Rect2(Vector2(floorf((size.x - book.x - markWidth) * 0.5), top), book)
	var inner : Rect2 = bookRect.grow(-cover)
	var half : float = columns * step() - cellGap + padding * 2.0 + 3.0
	leftRect = Rect2(inner.position, Vector2(half, inner.size.y))
	rightRect = Rect2(leftRect.end.x + spine, inner.position.y, inner.end.x - leftRect.end.x - spine, inner.size.y)
	var button : Vector2 = Vector2.ONE * buttonSize
	prevRect = Rect2(leftRect.position + Vector2(padding, padding - 1.0), button)
	nextRect = Rect2(Vector2(leftRect.end.x - padding - buttonSize, prevRect.position.y), button)
	titleRect = Rect2(prevRect.end.x + 1.0, prevRect.position.y, nextRect.position.x - prevRect.end.x - 2.0, buttonSize)
	var gridTop : float = prevRect.end.y + 2.0
	tabRects.clear()
	if has_tabs():
		var tabWidth : float = floorf((columns * step() - cellGap) * 0.5)
		tabRects = [Rect2(leftRect.position.x + padding, gridTop, tabWidth - 1.0, 8.0), Rect2(leftRect.position.x + padding + tabWidth, gridTop, tabWidth, 8.0)]
		gridTop += 10.0
	gridRect = Rect2(leftRect.position.x + padding, gridTop, columns * step() - cellGap, leftRect.end.y - padding - gridTop)
	detailRect = Rect2(rightRect.position + Vector2.ONE * padding, rightRect.size - Vector2.ONE * padding * 2.0)
	markRects.clear()
	var y : float = bookRect.position.y + 4.0
	for mark in marks:
		markRects.append(Rect2(bookRect.end.x - 1.0, y, markWidth + 1.0, markHeight))
		y += markHeight + 1.0
	lay_contents()
	sheet.size = size
	grid.position = gridRect.position - Vector2.ONE
	grid.size = gridRect.size + Vector2.ONE * 2.0
	if not detailMotion or not detailMotion.is_running():
		detail.position = detailRect.position
	detail.size = detailRect.size
	tipLayer.size = size
	scroll = clampf(scroll, 0.0, max_scroll())
	refresh()

# The contents rows, filling the left page and then the right one.
func lay_contents() -> void:
	entries.clear()
	var wanted : Array[Array] = [["all", 0]]
	for mark in marks:
		if mark[2] < 0:
			continue
		wanted.append(["region", mark[2]])
		for i in journal.biomes.size():
			if region_of(journal.biomes[i]) == mark[2]:
				wanted.append(["page", i + 1])
	var pages : Array[Rect2] = [leftRect.grow(-padding), rightRect.grow(-padding)]
	var headTop : float = pages[0].position.y + ui.titleSize + 4.0
	var regions : int = 0
	for entry in wanted:
		if entry[0] == "region":
			regions += 1
	var room : float = (pages[0].end.y - headTop) + (pages[1].end.y - pages[1].position.y) - regions - 3.0
	var pitch : float = clampf(floorf(room / wanted.size() * 2.0) * 0.5, 4.0, 6.0)
	var page : int = 0
	var y : float = headTop
	for entry in wanted:
		if y + pitch > pages[page].end.y and page == 0:
			page = 1
			y = pages[1].position.y
		var area : Rect2 = Rect2(pages[page].position.x, y, pages[page].size.x, pitch)
		entries.append([entry[0], entry[1], area])
		y += pitch + (1.0 if entry[0] == "region" else 0.0)

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
	for i in markRects.size():
		if markRects[i].grow_individual(0.0, 0.0, 2.0, 0.0).has_point(point):
			return Vector2i(Zone.MARK, i)
	if mode == Mode.CONTENTS:
		for i in entries.size():
			if entries[i][0] != "region" and entries[i][2].has_point(point):
				return Vector2i(Zone.ENTRY, i)
		return Vector2i(Zone.NONE, -1)
	if prevRect.has_point(point):
		return Vector2i(Zone.PREV, 0)
	if nextRect.has_point(point):
		return Vector2i(Zone.NEXT, 0)
	if titleRect.has_point(point):
		return Vector2i(Zone.TITLE, 0)
	for i in tabRects.size():
		if tabRects[i].has_point(point):
			return Vector2i(Zone.TAB, i)
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
				if selected:
					select(null)
				elif mode == Mode.PAGE:
					show_contents()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var up : bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
				if mode == Mode.PAGE and detailRect.has_point(event.position):
					detailScroll = clampf(detailScroll + (-6.0 if up else 6.0), 0.0, detail_max_scroll())
					refresh()
				elif mode == Mode.PAGE and gridRect.has_point(event.position) and max_scroll() > 0.0:
					scroll = clampf(scroll + step() * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 0.0, max_scroll())
					hover_at(event.position)
					refresh()
		accept_event()

func click(at : Zone, index : int) -> void:
	match at:
		Zone.PREV:
			turn(-1)
		Zone.NEXT:
			turn(1)
		Zone.TITLE:
			show_contents()
		Zone.MARK:
			if marks[index][2] < 0:
				show_contents()
			else:
				show_region(marks[index][2])
		Zone.ENTRY:
			show_page(entries[index][1], 1)
		Zone.TAB:
			show_tab(index == 1)
		Zone.CELL:
			if creatureTab:
				pickedCreature = null if creatureList[index] == pickedCreature else creatureList[index]
				detailScroll = 0.0
				detailMotion = slide_in(detailMotion, detail, detailRect.position, Vector2(0.0, 2.0))
				refresh()
			else:
				select(null if list[index] == selected else list[index])
		_:
			if mode == Mode.PAGE and gridRect.has_point(mouse):
				select(null)

func detail_max_scroll() -> float:
	return maxf(detailHeight - detailRect.size.y, 0.0)

func select(data : FishData) -> void:
	if data == selected:
		return
	selected = data
	detailScroll = 0.0
	if data:
		journal.see(data)
	detailMotion = slide_in(detailMotion, detail, detailRect.position, Vector2(0.0, 2.0))
	refresh()

func hover_at(point : Vector2) -> void:
	var at : Vector2i = zone_at(point)
	hover(at.x as Zone, at.y, true)

func hover(at : Zone, index : int, force : bool = false) -> void:
	if not force and at == zone and index == hoveredIndex:
		return
	zone = at
	hoveredIndex = index
	update_tip()
	if zone == Zone.CELL and not creatureTab and index >= 0 and index < list.size() and journal.is_found(list[index], page_biome()):
		journal.see(list[index])
	grid.queue_redraw()
	sheet.queue_redraw()
	queue_redraw()

func update_tip() -> void:
	clear_tip()
	match zone:
		Zone.PREV, Zone.NEXT:
			var target : int = wrapi(pageIndex + (-1 if zone == Zone.PREV else 1), 0, page_count())
			var biome : Biome = page_biome(target)
			set_tip(biome.displayName if biome else allTitle, ui.textColor, PackedStringArray(["Arrow keys", ""]))
		Zone.TITLE:
			set_tip("Contents", ui.textColor, PackedStringArray(["Every fishing ground", "", "Esc or right click", ""]))
		Zone.MARK:
			if hoveredIndex >= 0 and hoveredIndex < marks.size():
				set_tip(marks[hoveredIndex][0], marks[hoveredIndex][1].lightened(0.3), PackedStringArray())
		Zone.TAB:
			set_tip("Sea creatures" if hoveredIndex == 1 else "Fish", ui.textColor, PackedStringArray())
		Zone.CELL:
			if creatureTab and hoveredIndex >= 0 and hoveredIndex < creatureList.size():
				var creature : SeaCreature = creatureList[hoveredIndex]
				if beaten(creature):
					set_tip(creature.displayName, creature.rarity.color if creature.rarity else ui.textColor, PackedStringArray())
				else:
					set_tip("Not beaten yet", ui.dimColor, PackedStringArray(["Fishing", "%d+" % creature.minFishing]))
			elif hoveredIndex >= 0 and hoveredIndex < list.size():
				var data : FishData = list[hoveredIndex]
				if journal.is_found(data, page_biome()):
					set_tip(data.displayName, rarity_color(data), PackedStringArray())
				else:
					var lines : PackedStringArray = PackedStringArray(["Bites", data.hours_text()])
					for line in data.requirement_lines():
						lines.append_array([line, ""])
					set_tip(hiddenText, ui.dimColor, lines)

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

func _process(delta : float) -> void:
	time += delta
	if zone == Zone.MARK or zone == Zone.CELL or selected or pickedCreature:
		queue_redraw()
		grid.queue_redraw()
		sheet.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(bookRect.position + Vector2(2.0, 2.0), bookRect.size), Color(0.0, 0.0, 0.0, 0.3))
	for i in marks.size():
		draw_mark(i)
	UiKit.box(self, skin.frame, bookRect)
	UiKit.box(self, skin.well, leftRect)
	UiKit.box(self, skin.well, rightRect)
	var middle : float = floorf(leftRect.end.x + spine * 0.5)
	draw_rect(Rect2(middle - 1.0, bookRect.position.y + 1.0, 3.0, bookRect.size.y - 2.0), Color(0.18, 0.05, 0.05))
	draw_rect(Rect2(leftRect.end.x - 3.0, leftRect.position.y + 1.0, 3.0, leftRect.size.y - 2.0), Color(0.4, 0.28, 0.15, 0.18))
	draw_rect(Rect2(rightRect.position.x, rightRect.position.y + 1.0, 3.0, rightRect.size.y - 2.0), Color(0.4, 0.28, 0.15, 0.18))

# A ribbon sticking out of the book's edge. The open region's sticks out more.
func draw_mark(index : int) -> void:
	var area : Rect2 = markRects[index]
	var mark : Array = marks[index]
	var open : bool = (mode == Mode.CONTENTS and mark[2] < 0) or (mode == Mode.PAGE and page_biome() != null and mark[2] == region_of(page_biome()))
	var hovering : bool = zone == Zone.MARK and hoveredIndex == index
	var out : float = 2.0 if open else (1.0 + roundf(0.5 + 0.5 * sin(time * 8.0)) if hovering else 0.0)
	var shown_area : Rect2 = Rect2(area.position, area.size + Vector2(out, 0.0))
	var color : Color = mark[1]
	draw_rect(shown_area.grow(1.0), Color(0.1, 0.03, 0.03))
	draw_rect(shown_area, color)
	draw_rect(Rect2(shown_area.position, Vector2(shown_area.size.x, 1.0)), color.lightened(0.35))
	draw_rect(Rect2(shown_area.end.x - 1.0, shown_area.position.y, 1.0, shown_area.size.y), color.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(shown_area.end.x - 1.0, shown_area.position.y + 2.0), Vector2(shown_area.end.x - 1.0, shown_area.end.y - 2.0), Vector2(shown_area.end.x - 3.0, shown_area.get_center().y)]), Color(0.1, 0.03, 0.03))

# The page header and progress above the grid, the contents, and the scroll bar.
func draw_sheet() -> void:
	var font : Font = ui.font
	if mode == Mode.CONTENTS:
		draw_contents(font)
		return
	var biome : Biome = page_biome()
	var title : String = biome.displayName if biome else allTitle
	var band : Color = region_color(biome)
	sheet.draw_rect(Rect2(leftRect.position.x + 1.0, leftRect.position.y + 1.0, leftRect.size.x - 2.0, 1.0), band)
	draw_arrow(prevRect, -1.0, zone == Zone.PREV)
	draw_arrow(nextRect, 1.0, zone == Zone.NEXT)
	var count : String = "%d/%d" % [journal.found_in(list, biome), list.size()]
	var countWidth : float = UiKit.text_width(font, count, ui.statSize)
	var baseline : float = UiKit.baseline(font, titleRect, ui.titleSize)
	var titleColor : Color = skin.title.lightened(0.15) if zone == Zone.TITLE else skin.title
	UiKit.label(sheet, font, Vector2(titleRect.position.x + 1.0, baseline), title, ui.titleSize, titleColor, HORIZONTAL_ALIGNMENT_LEFT, titleRect.size.x - countWidth - 3.0)
	if zone == Zone.TITLE:
		var width : float = minf(UiKit.text_width(font, title, ui.titleSize), titleRect.size.x - countWidth - 3.0)
		sheet.draw_rect(Rect2(titleRect.position.x + 1.0, baseline + 1.0, width, 1.0), Color(titleColor, 0.6))
	UiKit.label(sheet, font, Vector2(titleRect.end.x - countWidth, baseline), count, ui.statSize, skin.dim)
	if selected and not creatureTab and detailScroll <= 0.0:
		UiKit.label(sheet, font, Vector2(detailRect.position.x, detailRect.position.y + font.get_ascent(ui.statSize)), "No. %02d" % (list.find(selected) + 1), ui.statSize, skin.dim)
	for i in tabRects.size():
		var on : bool = (i == 1) == creatureTab
		var hovering : bool = zone == Zone.TAB and hoveredIndex == i
		UiKit.paper_tab(sheet, font, tabRects[i], "Creatures" if i == 1 else "Fish", on, hovering, skin.title, skin.dim)
	var deepest : float = detail_max_scroll()
	if deepest > 0.0:
		var bar : Rect2 = Rect2(detailRect.end.x + 1.0, detailRect.position.y, 1.0, detailRect.size.y)
		var knob : float = maxf(bar.size.y * bar.size.y / (bar.size.y + deepest), 4.0)
		sheet.draw_rect(bar, skin.line)
		sheet.draw_rect(Rect2(bar.position.x, bar.position.y + (bar.size.y - knob) * detailScroll / deepest, 1.0, knob), skin.dim)
	var most : float = max_scroll()
	if most > 0.0:
		var track : Rect2 = Rect2(gridRect.end.x + 1.0, gridRect.position.y, 1.0, gridRect.size.y)
		var length : float = maxf(track.size.y * track.size.y / (track.size.y + most), 4.0)
		sheet.draw_rect(track, skin.line)
		sheet.draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - length) * scroll / most, 1.0, length), skin.dim)

func draw_arrow(area : Rect2, direction : float, lit : bool) -> void:
	var color : Color = skin.title if lit else skin.dim
	var tip : Vector2 = area.get_center() + Vector2(direction * 1.5, 0.0)
	var back : float = tip.x - direction * 3.0
	sheet.draw_colored_polygon(PackedVector2Array([tip, Vector2(back, tip.y - 2.0), Vector2(back, tip.y + 2.0)]), color)

func draw_contents(font : Font) -> void:
	var page : Rect2 = leftRect.grow(-padding)
	UiKit.label(sheet, font, Vector2(page.position.x, page.position.y + font.get_ascent(ui.titleSize)), "Contents", ui.titleSize, skin.title)
	var total : int = journal.all_fish().size()
	var found : int = journal.found_in(journal.all_fish())
	var share : String = "%d%%" % roundi(100.0 * found / maxf(total, 1.0))
	UiKit.label(sheet, font, Vector2(page.position.x, page.position.y + font.get_ascent(ui.titleSize)), share, ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, page.size.x)
	for i in entries.size():
		var entry : Array = entries[i]
		var area : Rect2 = entry[2]
		var hovering : bool = zone == Zone.ENTRY and hoveredIndex == i
		var baseline : float = UiKit.baseline(font, area, ui.statSize)
		match entry[0]:
			"region":
				var color : Color = REGIONS[entry[1]][1]
				sheet.draw_rect(Rect2(area.position.x, area.position.y + 1.0, 2.0, area.size.y - 1.0), color)
				UiKit.label(sheet, font, Vector2(area.position.x + 4.0, baseline), REGIONS[entry[1]][0], ui.statSize, color.darkened(0.5))
			_:
				var biome : Biome = page_biome(entry[1]) if entry[0] == "page" else null
				var fish : Array[FishData] = biome.fish if biome else journal.all_fish()
				var have : int = journal.found_in(fish, biome)
				var label : String = biome.displayName if biome else allTitle
				if hovering:
					sheet.draw_rect(area, skin.hover)
				var indent : float = 6.0 if biome else 0.0
				var color : Color = skin.text if have > 0 or not biome else skin.dim
				var count : String = "%d/%d" % [have, fish.size()]
				var countWidth : float = UiKit.text_width(font, count, ui.statSize)
				UiKit.label(sheet, font, Vector2(area.position.x + indent + (1.0 if hovering else 0.0), baseline), label, ui.statSize, color, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - indent - countWidth - 3.0)
				var done : bool = have >= fish.size() and not fish.is_empty()
				UiKit.label(sheet, font, Vector2(area.end.x - countWidth, baseline), count, ui.statSize, skin.good if done else skin.dim)

func draw_grid() -> void:
	if mode != Mode.PAGE:
		return
	var origin : Vector2 = Vector2.ONE
	var things : Array = shown_things()
	for i in cells.size():
		var area : Rect2 = cell_rect(i)
		area.position += origin
		if area.end.y < 0.0 or area.position.y > grid.size.y:
			continue
		var thing : Resource = things[i]
		var rarity : Rarity = thing.get("rarity")
		var icon : Texture2D = thing.get("icon")
		var found : bool = beaten(thing) if creatureTab else journal.is_found(thing, page_biome())
		var picked : bool = thing == (pickedCreature if creatureTab else selected)
		grid.draw_rect(area, cellEdge)
		grid.draw_rect(area.grow(-1.0), cellColor)
		if found and rarity:
			grid.draw_rect(Rect2(area.position.x + 1.0, area.end.y - 2.0, area.size.x - 2.0, 1.0), Color(rarity.color.darkened(0.2), 0.8))
		if picked or (i == hoveredIndex and zone == Zone.CELL):
			UiKit.brackets(grid, area, skin.title if picked else skin.dim, time)
		if not icon:
			continue
		var fit : float = minf(1.0, (minf(area.size.x, area.size.y) - 2.0) / (maxf(icon.get_width(), icon.get_height()) + 2.0)) if creatureTab else 1.0
		if found:
			ui.draw_icon(grid, icon, area.get_center(), Color.WHITE, ui.rarity_outline(rarity), fit)
			if not creatureTab and journal.unseen.has(thing):
				grid.draw_rect(Rect2(area.end.x - 3.0, area.position.y + 1.0, 2.0, 2.0), newColor)
		else:
			ui.draw_silhouette(grid, icon, area.get_center(), silhouetteColor, fit)

func draw_detail() -> void:
	if mode != Mode.PAGE:
		return
	# Everything on the right page is drawn shifted up by the scroll; the
	# lowest point reached sets how far it can scroll.
	detail.draw_set_transform(Vector2(0.0, -detailScroll))
	var bottom : float = 0.0
	if creatureTab:
		bottom = draw_creature_page(pickedCreature) if pickedCreature else draw_creature_list()
	elif selected:
		bottom = draw_fish_page(selected)
	else:
		bottom = draw_progress()
	detail.draw_set_transform(Vector2.ZERO)
	detailHeight = bottom + 2.0
	detailScroll = clampf(detailScroll, 0.0, detail_max_scroll())

func draw_fish_page(data : FishData) -> float:
	var font : Font = ui.font
	var width : float = detailRect.size.x
	var found : bool = journal.is_found(data, page_biome())
	var y : float = buttonSize + 2.0
	if data.icon:
		var box : float = (data.icon.get_height() + 2.0) * detailScale
		if found:
			ui.draw_icon(detail, data.icon, Vector2(width * 0.5, y + box * 0.5), Color.WHITE, ui.rarity_outline(data.rarity), detailScale)
		else:
			ui.draw_silhouette(detail, data.icon, Vector2(width * 0.5, y + box * 0.5), silhouetteColor, detailScale)
		y += box + 2.0
	y = centered_text(data.displayName if found else "???", y, ui.titleSize, skin.readable(rarity_color(data)) if found else skin.text)
	if data.rarity:
		y = centered_text(data.rarity.displayName, y, ui.statSize, skin.readable(rarity_color(data)))
	y += 2.0
	var text : String = data.description if found else hiddenText
	if not text.is_empty():
		y = paragraph(text, y, skin.dim) + 2.0
	var stats : PackedStringArray = PackedStringArray()
	if found:
		stats.append_array(["Caught", "%d" % journal.count(data), "Best", "%.2fkg" % journal.best(data), "Size", data.weight_range_text()])
	var places : PackedStringArray = journal.biome_names(data)
	if not places.is_empty():
		stats.append_array(["Where", places[0] + (" +%d" % (places.size() - 1) if places.size() > 1 else "")])
	stats.append_array(["When", data.hours_text()])
	for i in range(0, stats.size() - 1, 2):
		var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
		detail.draw_string(font, baseline, stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, skin.dim)
		detail.draw_string(font, baseline, stats[i + 1], HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, skin.text)
		y += ui.statSize + 1.0
	for line in data.requirement_lines():
		y = paragraph(line, y + 1.0, skin.accent)
	return y

# How much of the page has been found, overall and per rarity.
func draw_progress() -> float:
	var font : Font = ui.font
	var width : float = detailRect.size.x
	var biome : Biome = page_biome()
	var found : int = journal.found_in(list, biome)
	var y : float = buttonSize + 3.0
	y = centered_text("Discovered", y, ui.statSize, skin.dim)
	y = centered_text("%d/%d" % [found, list.size()], y + 1.0, ui.titleSize, skin.text) + 1.0
	UiKit.bar(detail, Rect2(0.0, y, width, 4.0), float(found) / maxf(list.size(), 1.0), barColor, Color(0.5, 0.4, 0.28))
	y += 7.0
	if found == list.size() and not list.is_empty():
		y = centered_text(completeText, y, ui.statSize, skin.good) + 2.0
	var rarities : Array[Rarity] = []
	for data in list:
		if data.rarity and not rarities.has(data.rarity):
			rarities.append(data.rarity)
	for rarity in rarities:
		var ofRarity : Array[FishData] = []
		ofRarity.assign(list.filter(func(data : FishData) -> bool: return data.rarity == rarity))
		var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
		detail.draw_string(font, baseline, rarity.displayName, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, skin.readable(rarity.color))
		detail.draw_string(font, baseline, "%d/%d" % [journal.found_in(ofRarity, biome), ofRarity.size()], HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, skin.text)
		y += ui.statSize + 1.0
	if biome and biome.region != "Festivals":
		y = draw_rare(font, biome, y + 2.0)
	var text : String = biome.description if biome else allDescription
	if not text.is_empty():
		y = paragraph(text, y + 3.0, skin.dim)
	return y

# The creatures of this ground: how many are beaten, and a nudge to click one.
func draw_creature_list() -> float:
	var y : float = buttonSize + 3.0
	var done : int = creatureList.filter(func(c : SeaCreature) -> bool: return beaten(c)).size()
	y = centered_text("Sea creatures", y, ui.statSize, skin.dim)
	y = centered_text("%d/%d beaten" % [done, creatureList.size()], y + 1.0, ui.titleSize, skin.text) + 1.0
	UiKit.bar(detail, Rect2(0.0, y, detailRect.size.x, 4.0), float(done) / maxf(creatureList.size(), 1.0), barColor, Color(0.5, 0.4, 0.28))
	y += 7.0
	y = paragraph("Sometimes something bigger than a fish takes the bait here. Beat one to learn about it, or click one to see what's known.", y, skin.dim)
	return y

# One creature: its picture, name, what it is, when it bites, what it pays
# and what it drops (only once beaten).
func draw_creature_page(creature : SeaCreature) -> float:
	var font : Font = ui.font
	var width : float = detailRect.size.x
	var known : bool = beaten(creature)
	var y : float = buttonSize + 2.0
	var color : Color = creature.rarity.color if creature.rarity else ui.textColor
	if creature.icon:
		var zoom : float = minf(detailScale, 40.0 / maxf(creature.icon.get_width(), creature.icon.get_height()))
		var box : float = (creature.icon.get_height() + 2.0) * zoom
		if known:
			ui.draw_icon(detail, creature.icon, Vector2(width * 0.5, y + box * 0.5), Color.WHITE, ui.rarity_outline(creature.rarity), zoom)
		else:
			ui.draw_silhouette(detail, creature.icon, Vector2(width * 0.5, y + box * 0.5), silhouetteColor, zoom)
		y += box + 2.0
	y = centered_text(creature.displayName if known else "???", y, ui.titleSize, skin.readable(color) if known else skin.text)
	if creature.rarity:
		y = centered_text(creature.rarity.displayName + " creature", y, ui.statSize, skin.readable(color))
	y += 2.0
	y = paragraph(creature.description if known and not creature.description.is_empty() else "Not beaten yet.", y, skin.dim) + 2.0
	var stats : PackedStringArray = PackedStringArray()
	if known:
		stats.append_array(["Beaten", "%d" % player.progress.bestiary.get(creature, 0), "Coins", "%d-%d" % [creature.coins.x, creature.coins.y]])
	stats.append_array(["Fishing", "Lv %d+" % creature.minFishing, "When", hours_text(creature.hours)])
	for i in range(0, stats.size() - 1, 2):
		var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
		detail.draw_string(font, baseline, stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, skin.dim)
		detail.draw_string(font, baseline, stats[i + 1], HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, skin.text)
		y += ui.statSize + 1.0
	if known and not creature.drops.is_empty():
		y += 1.0
		detail.draw_string(font, Vector2(0.0, y + font.get_ascent(ui.statSize)), "Drops", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, skin.title)
		y += ui.statSize + 1.0
		for i in creature.drops.size():
			var drop : Item = creature.drops[i]
			if not drop:
				continue
			var chance : float = creature.dropChances[i] if i < creature.dropChances.size() else 1.0
			var baseline : Vector2 = Vector2(0.0, y + font.get_ascent(ui.statSize))
			detail.draw_string(font, baseline, drop.displayName, HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, ui.statSize, skin.text)
			detail.draw_string(font, baseline, "%d%%" % roundi(chance * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, skin.dim)
			y += ui.statSize + 1.0
	return y

static func hours_text(hours : Vector2) -> String:
	if is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0)):
		return "Any time"
	return "%d:00-%d:00" % [int(fposmod(hours.x, 24.0)), int(fposmod(hours.y, 24.0))]

# The rare catches of this ground, with how full each one's luck meter is.
func draw_rare(font : Font, biome : Biome, y : float) -> float:
	var drops : Array[RareDrop] = RareDrops.for_biome(biome)
	if drops.is_empty():
		return y
	var width : float = detailRect.size.x
	detail.draw_string(font, Vector2(0.0, y + font.get_ascent(ui.statSize)), "Rare catches", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, skin.title)
	y += ui.statSize + 2.0
	for i in mini(drops.size(), 3):
		var drop : RareDrop = drops[i]
		var found : bool = player.progress.collected.has(drop.item)
		var label : String = drop.item.displayName if found else "???"
		detail.draw_string(font, Vector2(0.0, y + font.get_ascent(ui.statSize)), label, HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, ui.statSize, skin.text if found else skin.dim)
		detail.draw_string(font, Vector2(0.0, y + font.get_ascent(ui.statSize)), "1/%d" % roundi(1.0 / maxf(drop.chance, 0.0001)), HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, skin.dim)
		y += ui.statSize + 1.0
		UiKit.bar(detail, Rect2(0.0, y, width, 2.0), float(RareDrops.meter(player.progress, drop)) / drop.pity_count(), Color(0.85, 0.35, 0.7), Color(0.5, 0.4, 0.28))
		y += 3.0
	return y

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
