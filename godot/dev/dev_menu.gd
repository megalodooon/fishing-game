extends MenuPanel
class_name DevMenu

# Developer cheats on the 0 key: money, items, pets, a maxed rod, forced
# rarities, time skips and travel. Toggles show ON/OFF on their button.

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var world : World
@export var cycle : DayNightCycle
@export var notices : NoticeBoard
@export var columns : int = 3
@export var buttonSize : Vector2 = Vector2(58.0, 8.0)
@export var onColor : Color = Color(0.56, 0.93, 0.44)

var grid : GridContainer
var toggles : Dictionary = {}
#------------------------#


func _ready() -> void:
	super()
	slide = Vector2.ZERO
	set_anchors_preset(PRESET_TOP_LEFT)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(ui.panelColor, ui.frameColor, 2.0))
	add_child(panel)
	var column : VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var title : Label = Label.new()
	title.text = "Developer menu (0 to close)"
	title.add_theme_font_override("font", ui.font)
	title.add_theme_font_size_override("font_size", ui.titleSize)
	title.add_theme_color_override("font_color", ui.selectedColor)
	column.add_child(title)
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(columns * (buttonSize.x + 1.0), 86.0)
	column.add_child(scroll)
	var bar : VScrollBar = scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 2.0
	bar.add_theme_stylebox_override("scroll", box(ui.slotColor, ui.slotColor, 0.0))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, box(ui.hoverColor, ui.hoverColor, 0.0))
	grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	scroll.add_child(grid)
	toggle("Legendary", "legendaryCatches")
	toggle("Trophy", "trophyCatches")
	toggle("Instant bites", "instantBites")
	toggle("Auto-win", "autoWin")
	toggle("No energy use", "infiniteEnergy")
	button("+1000 coins", func() -> void: player.wallet.add(1000))
	button("Refill energy", func() -> void: player.energy.refill(1.0))
	button("Max rod", max_rod)
	button("All tackle x9", all_tackle)
	button("All bait x20", all_bait)
	button("Seeds+crops x20", seeds_and_crops)
	button("Snacks x10", func() -> void: give_folder("res://items/snacks", 10))
	button("Random pet", random_pet)
	button("Max pet level", max_pet)
	button("Fill aquarium", fill_aquarium)
	button("Fill journal", fill_journal)
	button("Unlock places", unlock_places)
	button("Grow farm", grow_farm)
	button("Reset secrets", reset_secrets)
	button("All rods", func() -> void: give_folder("res://fishing/rods", 1))
	button("Meals x5", func() -> void: give_folder("res://items/snacks", 5))
	button("Quest goals done", finish_quest_goals)
	button("Rain", func() -> void: force_weather(Weather.State.RAIN))
	button("Fog", func() -> void: force_weather(Weather.State.FOG))
	button("Clear sky", func() -> void: force_weather(Weather.State.CLEAR))
	button("Natural weather", func() -> void: force_weather(-1))
	button("+1 hour", func() -> void: cycle.advance(1.0))
	button("Next day", func() -> void: cycle.set_day(cycle.day + 1))
	button("To Sunday", func() -> void: cycle.set_day(cycle.day + posmod(DayNightCycle.SUNDAY - cycle.weekday(), 7)))
	button("To Friday", func() -> void: cycle.set_day(cycle.day + posmod(DayNightCycle.Weekday.FRIDAY - cycle.weekday(), 7)))
	button("Time 1:00", func() -> void: cycle.set_time(1.0))
	button("Time 12:00", func() -> void: cycle.set_time(12.0))
	for event in GameEvent.all():
		button("Start: " + event.displayName, start_event.bind(event))
	button("Festival items x20", func() -> void: give_folder("res://items/events", 20))
	button("Rare catches x3", func() -> void: give_folder("res://items/rare", 3))
	button("Tools and bags", func() -> void: give_folder("res://items/tools", 1))
	button("Materials x30", func() -> void: give_folder("res://items/materials", 30))
	button("Skills +5 levels", skills_up)
	button("Fill luck meters", fill_luck)
	for location in player.atlas.locations:
		button("Go: " + location.displayName, travel.bind(location))
	ui.laid_out.connect(fit)
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	var panel : Control = get_child(0)
	panel.reset_size()
	panel.position = ((ui.size - panel.size) * 0.5).floor()

func box(fill : Color, border : Color, margin : float) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	return style

func button(text : String, action : Callable) -> Button:
	var made : Button = Button.new()
	made.text = text
	made.focus_mode = FOCUS_NONE
	made.custom_minimum_size = buttonSize
	made.clip_text = true
	made.add_theme_font_override("font", ui.font)
	made.add_theme_font_size_override("font_size", ui.statSize)
	made.add_theme_color_override("font_color", ui.textColor)
	made.add_theme_color_override("font_hover_color", ui.selectedColor)
	made.add_theme_stylebox_override("normal", box(ui.slotColor, ui.frameColor, 1.0))
	made.add_theme_stylebox_override("hover", box(ui.slotColor.lightened(0.1), ui.hoverColor, 1.0))
	made.add_theme_stylebox_override("pressed", box(ui.frameColor, ui.selectedColor, 1.0))
	made.pressed.connect(func() -> void:
		action.call()
		notices.post("Dev", text, ui.selectedColor))
	grid.add_child(made)
	return made

func toggle(text : String, flag : String) -> void:
	var made : Button = button(text, func() -> void: Dev.flip(flag))
	toggles[made] = [text, flag]
	made.pressed.connect(refresh_toggles)
	refresh_toggles()

func refresh_toggles() -> void:
	for made : Button in toggles:
		var on : bool = Dev.flag(toggles[made][1])
		made.text = "%s: %s" % [toggles[made][0], "ON" if on else "off"]
		made.add_theme_color_override("font_color", onColor if on else ui.textColor)

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("dev_menu") or (shown and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle_menu()

func close() -> void:
	close_menu()

func _has_point(point : Vector2) -> bool:
	return shown and (get_child(0) as Control).get_rect().has_point(point)

# The held rod, or the first one in the bag, gets the rarest part of each
# slot's kind (and plenty of copies to spare).
func max_rod() -> void:
	var rod : RodItem = player.held_data() as RodItem
	if not rod:
		for item in player.inventory.items:
			if item is RodItem:
				rod = item
				break
	if not rod:
		return
	all_tackle()
	all_bait()
	for slot in rod.slots.size():
		var best : Tackle = null
		for part in player.tacklebox.parts_of(rod.slots[slot]):
			if not best or rank(part) >= rank(best):
				best = part
		if best:
			rod.set_tackle(slot, best)

func rank(part : Tackle) -> float:
	return part.rarity.difficulty if part.rarity else 0.0

func all_tackle() -> void:
	for part in player.tacklebox.catalog:
		if part and not part is Bait:
			player.tacklebox.add(part, 9)

func all_bait() -> void:
	for bait in Dev.load_all("res://fishing/bait"):
		if bait is Bait:
			player.tacklebox.add(bait, 20)

func seeds_and_crops() -> void:
	give_folder("res://world/village/farm/seeds", 20)
	give_folder("res://items/materials", 20)

func give_folder(folder : String, amount : int) -> void:
	for item in Dev.load_all(folder):
		if item is Item:
			player.inventory.give(item, amount)

func random_pet() -> void:
	var pets : Array[PetData] = []
	var fresh : Array[PetData] = []
	for pet in Dev.load_all("res://world/village/pets"):
		if pet is PetData:
			pets.append(pet)
			if not player.progress.pets.has(pet):
				fresh.append(pet)
	if pets.is_empty():
		return
	var pick : PetData = fresh.pick_random() if not fresh.is_empty() else pets.pick_random()
	if not player.progress.pets.has(pick):
		player.progress.pets.append(pick)
	player.progress.set_active_pet(pick)

func max_pet() -> void:
	var pet : PetData = player.progress.activePet
	if pet and not pet.levelCatches.is_empty():
		player.progress.petCatches[pet] = pet.levelCatches[pet.levelCatches.size() - 1]
		player.progress.emit_changed()

func fill_aquarium() -> void:
	for tank in Dev.load_all("res://world/village/aquarium/tanks"):
		if tank is AquariumTank:
			for data in tank.fish:
				player.progress.donate(tank, data)

func fill_journal() -> void:
	for biome in player.journal.biomes:
		for data in biome.fish:
			if data:
				player.journal.record(Fish.caught(data), biome)

func unlock_places() -> void:
	for location in player.atlas.locations:
		if not player.atlas.is_unlocked(location):
			player.atlas.unlocked.append(location)
	player.atlas.emit_changed()

func grow_farm() -> void:
	for id in player.progress.farms:
		for tile in player.progress.farms[id]:
			if not tile.is_empty():
				tile[1] = cycle.day - (tile[0] as Seed).days
	player.progress.emit_changed()

func force_weather(which : int) -> void:
	var weather : Weather = Weather.find(get_tree())
	if weather:
		weather.force(which)

# Every quest going counts as done, ready to hand in (except flags and tanks).
func finish_quest_goals() -> void:
	for quest in player.progress.active_quests():
		for i in quest.goals.size():
			var goal : QuestGoal = quest.goals[i]
			if goal.kind == QuestGoal.Kind.DELIVER:
				var kind : Item = goal.target as Item
				if kind:
					player.inventory.give(kind, goal.amount)
			else:
				player.progress.quests[quest].counts[i] = goal.amount
	player.progress.emit_changed()

func reset_secrets() -> void:
	for key in player.progress.flags.keys():
		if String(key).begins_with("secret/"):
			player.progress.flags.erase(key)
	player.progress.emit_changed()

# Straight there, standing on the boat's deck.
func travel(location : Location) -> void:
	player.wake_reset()
	player.global_position = world.boat.global_position + Vector2(-26.0, 3.0)
	if not player.atlas.is_unlocked(location):
		player.atlas.unlocked.append(location)
	world.arrive(location)

# Jumps to the first day of a festival, at an hour it's running.
func start_event(event : GameEvent) -> void:
	var wait : int = Calendar.days_until(event, cycle.day)
	if wait > 0:
		cycle.set_day(cycle.day + wait)
	if not event.on_hour(cycle.time):
		cycle.set_time(fposmod(event.hours.x + 0.5, 24.0))
	var director : EventDirector = EventDirector.find(get_tree())
	if director:
		director.check()

func skills_up() -> void:
	for skill in Skills.LIST:
		var level : int = Skills.level(player, skill)
		var needed : float = Skills.total_for(skill, mini(level + 5, Skills.MAX_LEVEL)) - Skills.xp(player, skill)
		Skills.add(player, skill, maxf(needed, 0.0) + 1.0)

func fill_luck() -> void:
	for drop in RareDrops.all():
		player.progress.pity[drop] = drop.pity_count() - 1
