extends RefCounted
class_name Settings

# Player settings, kept in user://settings.cfg between runs. The settings
# panel (on the title screen and in the pause menu) changes them; global ones
# (window, sound, keys) apply right away through apply_global, the in-game
# ones are read by the game when it starts and when they change.

const PATH : String = "user://settings.cfg"
const DEFAULTS : Dictionary = {
	"uiScale": 1.0,
	"hotbarOnTop": false,
	"heldItemScale": 0.75,
	"windowMode": "fullscreen",
	"vsync": true,
	"fpsCap": 0,
	"showFps": false,
	"weatherEffects": true,
	"screenShake": true,
	"reduceFlashing": false,
	"rarityLetters": false,
	"questTracker": true,
	"textSpeed": 1.0,
	"autosave": 10,
	"volume": 1.0,
	"musicVolume": 0.8,
	"sfxVolume": 1.0,
	# The name typed in last time, for joining friends.
	"playerName": "",
	# The last join code typed in.
	"lastCode": "",
	# Changed keys: action name to physical keycode (or -mouse button).
	"keys": {},
}
const WINDOW_MODES : PackedStringArray = ["fullscreen", "borderless", "windowed"]
const FPS_CAPS : PackedInt32Array = [0, 30, 60, 120, 144, 240]
const TEXT_SPEEDS : PackedFloat32Array = [0.5, 1.0, 2.0, 100.0]
const AUTOSAVES : PackedInt32Array = [0, 5, 10, 20]
# Keys that can be changed, in the order the controls page lists them.
const ACTIONS : Array[Array] = [
	["up", "Walk up"], ["down", "Walk down"], ["left", "Walk left"], ["right", "Walk right"],
	["interact", "Use / talk"], ["hub", "All menus"], ["backpack", "Bag"], ["tacklebox", "Tacklebox"],
	["journal", "Journal"], ["map", "Sea chart"], ["quests", "Quests"], ["recipes", "Recipes"],
	["profile", "Skills"], ["collections", "Collections"], ["calendar", "Calendar"], ["charms", "Equipment"],
	["pets", "Pets"], ["anchor", "Stop boat"], ["speed_up", "Boat faster"], ["slow_down", "Boat slower"],
	["slot_1", "Hotbar 1"], ["slot_2", "Hotbar 2"], ["slot_3", "Hotbar 3"], ["slot_4", "Hotbar 4"], ["slot_5", "Hotbar 5"],
]

static var values : Dictionary = DEFAULTS.duplicate(true)
static var loaded : bool = false
# Every action's keys as the project set them, for "reset".
static var originalKeys : Dictionary = {}


static func get_value(key : String) -> Variant:
	load_file()
	return values.get(key, DEFAULTS.get(key))

static func set_value(key : String, value : Variant) -> void:
	load_file()
	values[key] = value
	save_file()

static func load_file() -> void:
	if loaded:
		return
	loaded = true
	var file : ConfigFile = ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key in DEFAULTS:
		values[key] = file.get_value("settings", key, DEFAULTS[key])
	# Older files had a fullscreen switch.
	if file.has_section_key("settings", "fullscreen") and not file.has_section_key("settings", "windowMode"):
		values.windowMode = "fullscreen" if file.get_value("settings", "fullscreen") else "windowed"

static func save_file() -> void:
	var file : ConfigFile = ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	file.save(PATH)

# Things that don't need the game running: the window, frame rate, sound and keys.
static func apply_global() -> void:
	load_file()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		apply_window()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(values.fpsCap)
	set_bus("Master", float(values.volume))
	set_bus("Music", float(values.musicVolume))
	set_bus("SFX", float(values.sfxVolume))
	apply_keys()

static func apply_window() -> void:
	var mode : String = values.windowMode
	var current : DisplayServer.WindowMode = DisplayServer.window_get_mode()
	match mode:
		"windowed":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if current != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"borderless":
			if current != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen : int = DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			if current != DisplayServer.WINDOW_MODE_FULLSCREEN and current != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func set_bus(bus : String, volume : float) -> void:
	var index : int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)

# Puts the changed keys into the input map (the first key of each action).
static func apply_keys() -> void:
	if originalKeys.is_empty():
		for pair in ACTIONS:
			if InputMap.has_action(pair[0]):
				originalKeys[pair[0]] = InputMap.action_get_events(pair[0]).duplicate()
	for pair in ACTIONS:
		var action : String = pair[0]
		if not InputMap.has_action(action) or not originalKeys.has(action):
			continue
		InputMap.action_erase_events(action)
		var events : Array = originalKeys[action].duplicate()
		var custom : Variant = (values.keys as Dictionary).get(action)
		if custom != null and not events.is_empty():
			events[0] = event_for(int(custom))
		for event in events:
			InputMap.action_add_event(action, event)

static func event_for(code : int) -> InputEvent:
	if code < 0:
		var click : InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = -code as MouseButton
		return click
	var key : InputEventKey = InputEventKey.new()
	key.physical_keycode = code as Key
	return key

static func bind(action : String, event : InputEvent) -> void:
	var code : int = 0
	if event is InputEventKey:
		code = (event as InputEventKey).physical_keycode
	elif event is InputEventMouseButton:
		code = -(event as InputEventMouseButton).button_index
	if code == 0:
		return
	var keys : Dictionary = (get_value("keys") as Dictionary).duplicate()
	keys[action] = code
	set_value("keys", keys)
	apply_keys()

static func reset_keys() -> void:
	set_value("keys", {})
	apply_keys()

# What an action's first key is called, like "F" or "Mouse 1".
static func key_name(action : String) -> String:
	if not InputMap.has_action(action):
		return "-"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code : Key = (event as InputEventKey).physical_keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if code else (event as InputEventKey).keycode)
		if event is InputEventMouseButton:
			return "Mouse %d" % (event as InputEventMouseButton).button_index
	return "-"
