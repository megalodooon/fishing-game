extends RefCounted
class_name Cast

# Everyone who talks: their name and the color of their name tag. Each one's
# portrait is res://world/portraits/<id>.png (24x24 works best) and their
# standing sprite res://world/npcs/<id>.png, so new art is just a new file.

const PEOPLE : Dictionary = {
	"player": ["You", Color(0.94, 0.97, 1.0)],
	"narrator": ["", Color(0.8, 0.85, 0.95)],
	"pip": ["Harbor Master Pip", Color(0.55, 0.78, 1.0)],
	"nora": ["Nora", Color(0.45, 0.95, 0.85)],
	"gus": ["Gus the Fishmonger", Color(1.0, 0.72, 0.45)],
	"silas": ["Old Silas", Color(0.85, 0.8, 0.62)],
	"marina": ["Marina", Color(1.0, 0.6, 0.55)],
	"rex": ["Rex Marlow", Color(1.0, 0.85, 0.3)],
	"vera": ["Vera Voss", Color(0.8, 0.55, 1.0)],
	"brann": ["Smith Brann", Color(1.0, 0.5, 0.3)],
	"mara": ["Innkeeper Mara", Color(1.0, 0.62, 0.72)],
	"luma": ["Luma", Color(1.0, 0.95, 0.6)],
	"tilly": ["Tilly", Color(0.6, 0.95, 0.45)],
	"bo": ["Bo", Color(0.7, 0.9, 1.0)],
	"hale": ["Commissioner Hale", Color(0.9, 0.9, 0.95)],
	"opal": ["Opal the Diver", Color(0.75, 0.95, 1.0)],
	"grim": ["Captain Grim", Color(0.8, 0.7, 0.55)],
	"yuki": ["Yuki", Color(0.7, 0.9, 1.0)],
	"moss": ["Auntie Moss", Color(0.6, 0.85, 0.45)],
	"finn": ["Grandpa Finn", Color(1.0, 0.9, 0.55)],
	"wally": ["Wally the Walrus", Color(0.95, 0.45, 0.45)],
	"oriel": ["Oriel the Wanderer", Color(0.78, 0.55, 1.0)],
	"barnaby": ["Banker Barnaby", Color(0.55, 0.9, 0.6)],
	"odette": ["Odette", Color(0.55, 0.75, 1.0)],
}


static func name_of(id : String) -> String:
	return PEOPLE.get(id, [id.capitalize()])[0]

# The id of someone by the name shown for them, like "Harbor Master Pip".
static func id_of(shown : String) -> String:
	for id in PEOPLE:
		if PEOPLE[id][0] == shown:
			return id
	return ""

static func color_of(id : String) -> Color:
	return PEOPLE.get(id, ["", Color.WHITE])[1]

static func portrait(id : String) -> Texture2D:
	var path : String = "res://world/portraits/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
