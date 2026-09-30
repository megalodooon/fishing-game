extends RefCounted
class_name Preloader

# Loads the game's content on a background thread ahead of time, so opening
# the collection, catching something new or arriving somewhere never waits on
# the disk mid-game, and prepares the icon outlines the menus draw (see
# IconOutline). It starts on the title screen and the loading screen waits
# for it. Everything it loads stays in memory for the whole session.

# Everything the Catalog lists, the places and their scenes, and the rest of
# the data the menus show: pets, tanks, restoration projects, shops.
const FOLDERS : PackedStringArray = [
	Catalog.FISH_FOLDER, Catalog.CREATURE_FOLDER, Catalog.QUEST_FOLDER,
	"res://items", "res://fishing/bait", "res://fishing/tacklebox", "res://fishing/rods", "res://fishing/reforges",
	"res://world/village", "res://world/locations", "res://oceans", "res://world/events", "res://ui/skins",
]
# Pictures looked up by name while playing rather than held by a resource.
# Textures loaded for the first time while a menu draws come out white, so
# everything a menu looks up by name is loaded here first.
const PICTURE_FOLDERS : PackedStringArray = ["res://world/portraits", "res://boat/icons", "res://ui/hub/icons", "res://world/npcs"]
# Where the islands' land pictures are (in "land" folders).
const LAND_FOLDERS : PackedStringArray = ["res://world/islands", "res://world/village/land"]

static var thread : Thread
# Loaded without a thread, where threads aren't available.
static var loadedHere : bool = false
static var progress : float = 0.0
# Keeps what was loaded alive.
static var kept : Array[Resource] = []
# The Catalog's lists and the land's open rects, worked out on the thread
# and handed over once it's done.
static var catalog : Dictionary = {}
static var openRects : Dictionary = {}


# Set by stop: the thread gives up where it is.
static var stopping : bool = false


static func start() -> void:
	if thread or loadedHere:
		return
	thread = Thread.new()
	if thread.start(load_all) != OK:
		thread = null
		load_all()
		loadedHere = true

# One thread loading in order is faster here than a threaded request per
# file, which mostly wait on each other.
static func load_all() -> void:
	var paths : PackedStringArray = PackedStringArray()
	for folder in FOLDERS:
		collect(folder, paths, ["tres", "res"])
	for folder in PICTURE_FOLDERS:
		collect(folder, paths, ["png"])
	var loaded : Array[Resource] = []
	for i in paths.size():
		if stopping:
			return
		var resource : Resource = ResourceLoader.load(paths[i])
		if resource:
			loaded.append(resource)
			if resource is Location and not (resource as Location).scene.is_empty():
				var place : Resource = ResourceLoader.load((resource as Location).scene)
				if place:
					loaded.append(place)
		progress = float(i + 1) / paths.size() * 0.8
	var icons : Dictionary = {}
	for resource in loaded:
		for property in [&"icon", &"mapIcon", &"sprite"]:
			var icon : Texture2D = resource.get(property) as Texture2D
			if icon:
				icons[icon] = true
		if resource is Texture2D:
			icons[resource] = true
	var list : Array = icons.keys()
	for i in list.size():
		if stopping:
			return
		IconOutline.prepare(list[i])
		progress = 0.8 + float(i + 1) / list.size() * 0.2
	# Where the water shows past each island room's land (see Ocean.make_still).
	var lands : PackedStringArray = PackedStringArray()
	for folder in LAND_FOLDERS:
		collect(folder, lands, ["png"])
	for path in lands:
		if path.get_base_dir().get_file() == "land":
			var land : Texture2D = ResourceLoader.load(path) as Texture2D
			if land:
				loaded.append(land)
				openRects[land] = CanvasClip.find_open_rects(land)
	catalog = Catalog.build()
	kept = loaded

# Resource files in a folder and below. Exported games list imported and
# converted files with an extra ".import" or ".remap", which load all the same.
static func collect(folder : String, into : PackedStringArray, extensions : Array) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file in DirAccess.get_files_at(folder):
		var path : String = file.trim_suffix(".remap").trim_suffix(".import")
		if extensions.has(path.get_extension()) and not into.has(folder.path_join(path)):
			into.append(folder.path_join(path))
	for sub in DirAccess.get_directories_at(folder):
		collect(folder.path_join(sub), into, extensions)

# For quitting the game: the thread stops loading and is joined, so it
# doesn't outlive the engine.
static func stop() -> void:
	stopping = true
	if thread and thread.is_started():
		thread.wait_to_finish()

# How much is done, from 0 to 1. Joins the thread once it has finished.
static func poll() -> float:
	hand_over()
	return 1.0 if done() else progress

# Once the thread has finished: joins it and gives the Catalog its lists.
static func hand_over() -> void:
	if not done():
		return
	if thread and thread.is_started():
		thread.wait_to_finish()
	if not catalog.is_empty():
		Catalog.adopt(catalog)
		catalog = {}
	for land in openRects:
		if not CanvasClip.coverCache.has(land):
			CanvasClip.coverCache[land] = openRects[land]
	openRects = {}

static func done() -> bool:
	return loadedHere or (thread != null and not thread.is_alive())
