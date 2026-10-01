extends RefCounted

# Rebuilds Bramblewick from the old five-room village: one big island cut
# into 4x4 rooms (land from tools/placeholder_art, art_town), every node of
# the old village moved to its spot in LAYOUT, and the buildings with an
# inside turned into scenes of their own (res://world/village/insides/).
# Shops, people, quests and everything set on them come along unchanged.
# Run from the godot folder:
#   godot --headless --path . res://dev/harness.tscn -- out tool_village
# It reads world/village/village_old.tscn (kept as the source), so it can be
# run again after changing the layout.

const LAYOUT : GDScript = preload("res://../tools/village/layout.gd")
const SOURCE : String = "res://world/village/village_old.tscn"
const TARGET : String = "res://world/village/village.tscn"
const INSIDES : String = "res://world/village/insides/"

var old : Node
var rooms : Dictionary = {}
var waterBiome : Resource


func run() -> void:
	old = (load(SOURCE) as PackedScene).instantiate()
	waterBiome = old.get_node("Pier/Water").get("biome")
	var root : Node2D = old
	root.set("arrival", LAYOUT.ARRIVAL)
	make_rooms(root)
	var lamp : Node = old.get_node("Square/Lamp")
	for name in LAYOUT.INSIDE:
		make_inside(root, name, LAYOUT.INSIDE[name])
	for key in LAYOUT.SPOTS:
		var node : Node = old.get_node_or_null(key)
		if not node:
			print("MISSING ", key)
			continue
		place(node, LAYOUT.SPOTS[key])
	for i in LAYOUT.COTTAGES.size():
		var cottage : Node2D = building("Cottage%d" % (i + 1), "", "res://world/village/buildings/cottage.png")
		place(cottage, LAYOUT.COTTAGES[i])
	for i in LAYOUT.LAMPS.size():
		var copy : Node2D = lamp.duplicate()
		copy.name = "StreetLamp%d" % (i + 1)
		place(copy, LAYOUT.LAMPS[i])
	for spot in LAYOUT.STANDS:
		place(stand(spot[0], spot[1]), spot[2])
	for key in LAYOUT.DROP:
		var node : Node = old.get_node_or_null(key)
		if node:
			node.get_parent().remove_child(node)
			node.free()
	# Whatever is left in the old rooms goes with them.
	for name in ["Pier", "Square", "Home", "Lane", "Harbor"]:
		var room : Node = old.get_node(name)
		for child in room.get_children():
			if not child.name in ["Water", "Land"]:
				print("LEFT BEHIND ", name, "/", child.name)
		root.remove_child(room)
		room.free()
	save_scene(root, TARGET)
	root.free()
	check_land()

# Says which spots ended up in the sea.
func check_land() -> void:
	var land : Image = Image.load_from_file(ProjectSettings.globalize_path("res://world/village/land/town.png"))
	var spots : Dictionary = LAYOUT.SPOTS.duplicate()
	for i in LAYOUT.COTTAGES.size():
		spots["cottage %d" % i] = LAYOUT.COTTAGES[i]
	for i in LAYOUT.LAMPS.size():
		spots["lamp %d" % i] = LAYOUT.LAMPS[i]
	for spot in LAYOUT.STANDS:
		spots[spot[0]] = spot[2]
	for key in spots:
		var at : Vector2i = Vector2i(spots[key])
		if land.get_pixelv(at.clamp(Vector2i.ZERO, land.get_size() - Vector2i.ONE)).a <= 0.0:
			print("IN THE SEA ", key, " ", at)

func make_rooms(root : Node2D) -> void:
	var ocean : PackedScene = load("res://oceans/basic/basic_ocean.tscn")
	for y in LAYOUT.ROOMS.y:
		for x in LAYOUT.ROOMS.x:
			var room : IslandRoom = IslandRoom.new()
			room.name = "R%d_%d" % [x, y]
			room.size = LAYOUT.ROOM
			room.position = Vector2(x, y) * LAYOUT.ROOM
			room.y_sort_enabled = true
			root.add_child(room)
			var water : Node2D = ocean.instantiate()
			water.name = "Water"
			water.set("biome", waterBiome)
			room.add_child(water)
			var land : Sprite2D = Sprite2D.new()
			land.name = "Land"
			land.texture = load("res://world/village/land/town_%d_%d.png" % [x, y])
			land.centered = false
			land.z_index = -1
			room.add_child(land)
			room.land = [land]
			rooms[Vector2i(x, y)] = room

# Into the room under this island point.
func place(node : Node, at : Vector2) -> void:
	var cell : Vector2i = Vector2i(clampi(int(at.x / LAYOUT.ROOM.x), 0, LAYOUT.ROOMS.x - 1), clampi(int(at.y / LAYOUT.ROOM.y), 0, LAYOUT.ROOMS.y - 1))
	var room : IslandRoom = rooms[cell]
	if node.get_parent():
		node.get_parent().remove_child(node)
	room.add_child(node)
	node.position = at - room.position

# A building outside: its art standing on this node, and something solid.
func building(name : String, shown : String, art : String) -> Node2D:
	var node : Node2D = Node2D.new()
	node.name = name
	node.set_script(load("res://world/village/building.gd"))
	node.set("displayName", shown)
	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = load(art)
	sprite.centered = false
	var size : Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-floorf(size.x * 0.5), -size.y)
	node.add_child(sprite)
	node.add_child(body(Rect2(-size.x * 0.5 + 2.0, -10.0, size.x - 4.0, 9.0)))
	return node

func body(rect : Rect2) -> StaticBody2D:
	var solid : StaticBody2D = StaticBody2D.new()
	solid.name = "Body"
	var shape : CollisionShape2D = CollisionShape2D.new()
	shape.name = "Shape"
	var box : RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	solid.add_child(shape)
	return solid

# A piece of furniture: a picture standing on its bottom middle (so it sorts
# with people by its foot), solid where it stands when asked.
func furniture(parent : Node, name : String, art : String, foot : Vector2, solid : bool) -> Sprite2D:
	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = name
	sprite.texture = load(INSIDES + art + ".png")
	sprite.centered = false
	var size : Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-floorf(size.x * 0.5), -size.y)
	sprite.position = foot
	if solid:
		sprite.add_child(body(Rect2(-size.x * 0.5, -minf(size.y, 10.0), size.x, minf(size.y, 10.0))))
	parent.add_child(sprite)
	return sprite

func make_inside(root : Node2D, name : String, info : Dictionary) -> void:
	# The door outside.
	var outside : Node2D
	if not String(info.building).is_empty():
		outside = old.get_node(info.building)
	else:
		outside = building(name, name.capitalize().replace("Harbor Office", "Harbor Office"), "res://world/village/buildings/%s.png" % info.art)
		outside.set("displayName", {"HarborOffice": "Harbor Office", "Tavern": "The Salty Gull"}.get(name, name))
		place(outside, info.at)
	var door : Node2D = Node2D.new()
	door.name = "Entrance"
	door.set_script(load("res://world/village/entrance.gd"))
	door.set("inside", INSIDES + name.to_snake_case() + ".tscn")
	door.set("reach", 12.0)
	door.set("promptOffset", Vector2(0.0, -16.0))
	door.position = Vector2(0.0, 2.0)
	outside.add_child(door)
	# The inside.
	var island : Island = Island.new()
	island.name = name
	island.interior = true
	island.arrival = Vector2(96.0, 92.0)
	var room : IslandRoom = IslandRoom.new()
	room.name = name
	room.size = LAYOUT.ROOM
	room.y_sort_enabled = true
	island.add_child(room)
	var back : Sprite2D = Sprite2D.new()
	back.name = "Back"
	back.texture = load(INSIDES + info.floor + ".png")
	back.centered = false
	back.z_index = -2
	room.add_child(back)
	var floor_mask : Sprite2D = Sprite2D.new()
	floor_mask.name = "Floor"
	floor_mask.texture = load(INSIDES + info.floor + "_floor.png")
	floor_mask.centered = false
	floor_mask.modulate = Color(1.0, 1.0, 1.0, 0.0)
	floor_mask.z_index = -2
	room.add_child(floor_mask)
	room.land = [floor_mask]
	var leave : Node2D = Node2D.new()
	leave.name = "Exit"
	leave.set_script(load("res://world/village/exit.gd"))
	leave.position = Vector2(96.0, 103.0)
	leave.set("reach", 10.0)
	leave.set("promptOffset", Vector2(0.0, -6.0))
	room.add_child(leave)
	# Counters that were locked with the building outside stay locked inside,
	# in a stand-in building with the same lock.
	var lockHolder : Node2D = null
	if outside.get("unlockFlag") and not String(outside.get("unlockFlag")).is_empty() and name == "MarketHall":
		lockHolder = Node2D.new()
		lockHolder.name = "Store"
		lockHolder.set_script(load("res://world/village/building.gd"))
		for field in ["displayName", "unlockFlag", "unlockHint", "openDays", "openHours"]:
			lockHolder.set(field, outside.get(field))
		room.add_child(lockHolder)
		# Gus works in here from the start; only the store waits.
		outside.set("unlockFlag", "")
	for path in info.moves:
		var node : Node = old.get_node_or_null(path)
		if not node:
			print("MISSING inside ", path)
			continue
		node.get_parent().remove_child(node)
		var holder : Node = lockHolder if lockHolder and path == "Lane/MarketHall/Door" else room
		holder.add_child(node)
		node.position = info.moves[path] - (holder.position if holder != room else Vector2.ZERO)
	decorate(room, name)
	save_scene(island, INSIDES + name.to_snake_case() + ".tscn")

func decorate(room : Node, name : String) -> void:
	match name:
		"House":
			furniture(room, "BedArt", "bed", Vector2(56.0, 50.0), true)
			furniture(room, "Rug", "rug", Vector2(92.0, 84.0), false).z_index = -1
			furniture(room, "Table", "table", Vector2(112.0, 72.0), true)
			furniture(room, "Barrel", "barrel", Vector2(30.0, 92.0), true)
		"MarketHall":
			furniture(room, "FishCounter", "counter", Vector2(62.0, 58.0), true)
			furniture(room, "StoreCounter", "counter", Vector2(132.0, 58.0), true)
			furniture(room, "ShelfA", "shelf", Vector2(40.0, 34.0), false)
			furniture(room, "ShelfB", "shelf", Vector2(150.0, 34.0), false)
			furniture(room, "BarrelA", "barrel", Vector2(30.0, 92.0), true)
			furniture(room, "BarrelB", "barrel", Vector2(162.0, 92.0), true)
		"Bank":
			furniture(room, "Counter", "counter", Vector2(96.0, 58.0), true)
			furniture(room, "Vault", "vault", Vector2(150.0, 34.0), false)
			furniture(room, "Rug", "rug", Vector2(96.0, 90.0), false).z_index = -1
		"HarborOffice":
			furniture(room, "Desk", "counter", Vector2(96.0, 58.0), true)
			furniture(room, "Chart", "chart", Vector2(64.0, 30.0), false)
			furniture(room, "ShelfA", "shelf", Vector2(150.0, 34.0), false)
			furniture(room, "BarrelA", "barrel", Vector2(30.0, 92.0), true)
		"Museum":
			furniture(room, "TankA", "tank", Vector2(40.0, 56.0), true)
			furniture(room, "TankB", "tank", Vector2(40.0, 88.0), true)
			furniture(room, "CaseA", "case", Vector2(104.0, 76.0), true)
			furniture(room, "CaseB", "case", Vector2(128.0, 76.0), true)
			furniture(room, "Counter", "counter", Vector2(140.0, 54.0), true)
		"Tavern":
			furniture(room, "Bar", "bar", Vector2(96.0, 52.0), true)
			furniture(room, "Bottles", "bottles", Vector2(96.0, 30.0), false)
			furniture(room, "Hearth", "hearth", Vector2(150.0, 36.0), false)
			furniture(room, "TableA", "table", Vector2(44.0, 76.0), true)
			furniture(room, "TableB", "table", Vector2(140.0, 76.0), true)
			furniture(room, "BarrelA", "barrel", Vector2(30.0, 50.0), true)
			var board : Node2D = stand("DartBoard", 0)
			board.position = Vector2(56.0, 40.0)
			room.add_child(board)
			var wren : Node2D = Node2D.new()
			wren.name = "Npc_Wren"
			wren.set_script(load("res://world/npc/npc.gd"))
			wren.set("id", "wren")
			wren.set("greeting", "Sit anywhere that isn't sticky.")
			var art : Sprite2D = Sprite2D.new()
			art.name = "Art"
			art.texture = load("res://world/npcs/wren.png")
			wren.add_child(art)
			wren.set("art", art)
			wren.position = Vector2(96.0, 44.0)
			room.add_child(wren)

func stand(name : String, game : int) -> Node2D:
	var node : Node2D = Node2D.new()
	node.name = name
	node.set_script(load("res://world/arcade/arcade_stand.gd"))
	node.set("game", game)
	return node

# Saves a scene, owning every node made or moved here (but not the insides
# of scenes placed in it).
func save_scene(root : Node, path : String) -> void:
	claim(root, root)
	var packed : PackedScene = PackedScene.new()
	var error : Error = packed.pack(root)
	if error != OK:
		print("PACK FAILED ", path, " ", error)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	print("saved ", path, " ", ResourceSaver.save(packed, path))

func claim(node : Node, root : Node) -> void:
	for child in node.get_children():
		if child.owner == null or child.owner == old or child.owner == root:
			child.owner = root
			# An instance's own nodes stay its own.
			if child.scene_file_path.is_empty():
				claim(child, root)
