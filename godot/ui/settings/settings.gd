extends RefCounted
class_name Settings

# Player settings, kept in user://settings.cfg between runs. The pause menu
# changes them and applies them to the game.

const PATH : String = "user://settings.cfg"
const DEFAULTS : Dictionary = {
	"uiScale": 1.0,
	"hotbarOnTop": false,
	"heldItemScale": 0.75,
	"fullscreen": false,
	"weatherEffects": true,
	"questTracker": true,
	"volume": 1.0,
}

static var values : Dictionary = DEFAULTS.duplicate()
static var loaded : bool = false


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

static func save_file() -> void:
	var file : ConfigFile = ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	file.save(PATH)

# Things that don't need the game running, like the window and the volume.
static func apply_global() -> void:
	load_file()
	if not OS.has_feature("web"):
		var full : bool = values.fullscreen
		var mode : DisplayServer.WindowMode = DisplayServer.window_get_mode()
		var isFull : bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if full != isFull:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(values.volume), 0.0001)))
	AudioServer.set_bus_mute(0, float(values.volume) <= 0.0)
