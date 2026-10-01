extends Node

# Multiplayer (the "Net" autoload). Two players: the host runs the world and
# keeps the save, a guest joins with a join code. Everything goes through
# Godot's MultiplayerPeer, so another transport (Steam) only has to make a
# peer and hand it to start_host / start_guest.
#
# Messages are a kind and plain data (SaveGame.encode turns resources into
# paths), sent with send() and received by whoever registered with on().
# send_fast() is for things that are sent all the time and may drop, like
# where a player stands.
#
# Joining: the guest sends "hello" (name and version), the host answers with
# "welcome" (the world and the guest's own saved character, if any), the
# guest loads the game with that and says "ready". From then on NetSession
# (in the game scene) keeps the two games together.

signal peer_joined(id : int, who : String)
signal peer_left(id : int, who : String)
# Hosting or joining went wrong, or the other side went away.
signal failed(reason : String)
# The host's address is known (after trying to open the router's port).
signal address_ready(code : String, note : String)

enum Role { OFFLINE, HOST, GUEST }

const PORT : int = 24680
const PROTOCOL : String = "fishing-net-1"
const MAX_PLAYERS : int = 2
const CODE_ALPHABET : String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LOADING_SCENE : String = "res://ui/loading/loading_screen.tscn"
const TITLE_SCENE : String = "res://ui/title/title_screen.tscn"

var role : Role = Role.OFFLINE
var myName : String = ""
# Peer id to player name, for everyone who finished joining (not this one).
var names : Dictionary = {}
# Host only: every guest's character as last sent, by name, for the save.
var guestData : Dictionary = {}
# Message handlers by kind.
var handlers : Dictionary = {}
var joinCode : String = ""
var lanCode : String = ""
var addressNote : String = ""
var upnp : Object
var upnpThread : Thread
var mappedPort : int = 0
# Why the last session ended, shown by the title screen.
var lastError : String = ""
# A guest waiting for the host's answer to "hello".
var greeting : bool = false
#------------------------#


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(func() -> void: fail("Couldn't reach the host. Check the code and that the host is still in their world."))
	multiplayer.server_disconnected.connect(func() -> void: fail("The host left the game."))
	on(&"hello", on_hello)
	on(&"welcome", on_welcome)
	on(&"refused", func(_from : int, data : Variant) -> void: fail(str(data)))
	on(&"ready", on_ready)
	on(&"player_data", func(from : int, data : Variant) -> void:
		if is_host() and names.has(from):
			guestData[names[from]] = data)

static func supported() -> bool:
	return not OS.has_feature("web") and ClassDB.class_exists("ENetMultiplayerPeer")

func is_online() -> bool:
	return role != Role.OFFLINE

func is_host() -> bool:
	return role == Role.HOST

func is_guest() -> bool:
	return role == Role.GUEST

func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1

# Everyone else in the game, by peer id.
func others() -> Array:
	return names.keys()

func name_of(id : int) -> String:
	return myName if id == my_id() else names.get(id, "Friend")

func has_company() -> bool:
	return is_online() and not names.is_empty()

#------------------------# Hosting and joining

func host(port : int = PORT) -> Error:
	if not supported():
		return ERR_UNAVAILABLE
	var peer : MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
	var error : Error = peer.call("create_server", port, MAX_PLAYERS - 1)
	if error != OK:
		lastError = "Couldn't open port %d (is another game already hosting?)" % port
		return error
	start_host(peer)
	find_address(port)
	return OK

func start_host(peer : MultiplayerPeer) -> void:
	leave()
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	lastError = ""

func join(code : String, who : String) -> Error:
	if not supported():
		return ERR_UNAVAILABLE
	var address : Array = decode_address(code)
	if address.is_empty():
		lastError = "That code doesn't look right."
		return ERR_INVALID_PARAMETER
	var peer : MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
	var error : Error = peer.call("create_client", address[0], address[1])
	if error != OK:
		lastError = "Couldn't start connecting."
		return error
	myName = who
	start_guest(peer)
	return OK

func start_guest(peer : MultiplayerPeer) -> void:
	leave()
	multiplayer.multiplayer_peer = peer
	role = Role.GUEST
	greeting = true
	lastError = ""

# Back to playing alone (the host's guests are dropped).
func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.OFFLINE
	names.clear()
	greeting = false
	close_port()

func fail(reason : String) -> void:
	var wasGuest : bool = is_guest()
	lastError = reason
	leave()
	failed.emit(reason)
	# A guest's world was the host's, so there's nothing to go back to.
	if wasGuest and get_tree().current_scene and not get_tree().current_scene is CanvasLayer:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)

#------------------------# Messages

func on(kind : StringName, handler : Callable) -> void:
	if not handlers.has(kind):
		handlers[kind] = []
	handlers[kind].append(handler)

func off(kind : StringName, handler : Callable) -> void:
	if handlers.has(kind):
		handlers[kind].erase(handler)

# To everyone else, or only to one peer.
func send(kind : StringName, data : Variant = null, to : int = 0) -> void:
	if not is_online():
		return
	if to > 0:
		receive.rpc_id(to, kind, data)
	else:
		receive.rpc(kind, data)

func send_fast(kind : StringName, data : Variant = null, to : int = 0) -> void:
	if not is_online():
		return
	if to > 0:
		receive_fast.rpc_id(to, kind, data)
	else:
		receive_fast.rpc(kind, data)

@rpc("any_peer", "call_remote", "reliable")
func receive(kind : StringName, data : Variant) -> void:
	dispatch(multiplayer.get_remote_sender_id(), kind, data)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func receive_fast(kind : StringName, data : Variant) -> void:
	dispatch(multiplayer.get_remote_sender_id(), kind, data)

func dispatch(from : int, kind : StringName, data : Variant) -> void:
	# Until they've said hello, guests can only say hello.
	if is_host() and not names.has(from) and kind != &"hello":
		return
	for handler : Callable in handlers.get(kind, []).duplicate():
		if handler.is_valid():
			handler.call(from, data)

#------------------------# Joining

func on_peer_connected(_id : int) -> void:
	pass

func on_connected() -> void:
	send(&"hello", {"name": myName, "protocol": PROTOCOL, "version": ProjectSettings.get_setting("application/config/version", "")}, 1)

func on_hello(from : int, data : Variant) -> void:
	if not is_host() or not data is Dictionary:
		return
	var who : String = str(data.get("name", "")).strip_edges()
	var reason : String = ""
	var player : Player = Player.find(get_tree())
	if player:
		myName = player.progress.playerName
	if data.get("protocol", "") != PROTOCOL or data.get("version", "") != ProjectSettings.get_setting("application/config/version", ""):
		reason = "The host is playing a different version of the game."
	elif names.size() >= MAX_PLAYERS - 1:
		reason = "The game is full."
	elif who.is_empty() or who == myName or names.values().has(who):
		reason = "Someone called %s is already playing. Pick another name." % who
	if reason.is_empty() and not player:
		reason = "The host isn't in their world yet."
	if not reason.is_empty():
		send(&"refused", reason, from)
		multiplayer.multiplayer_peer.disconnect_peer.call_deferred(from)
		return
	names[from] = who
	send(&"welcome", {
		"host": myName,
		"hostId": my_id(),
		"world": SaveGame.world_data(player),
		"player": guestData.get(who, {}),
	}, from)

# The guest loads into the host's world.
func on_welcome(from : int, data : Variant) -> void:
	if not is_guest() or not greeting:
		return
	greeting = false
	names[from] = data.get("host", "Host")
	SaveGame.pending = {
		"version": SaveGame.VERSION,
		"you": myName,
		"world": data.get("world", {}),
		"players": {myName: data.get("player", {})},
	}
	SaveGame.newName = myName
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(LOADING_SCENE)

func on_ready(from : int, _data : Variant) -> void:
	if is_host() and names.has(from):
		peer_joined.emit(from, names[from])

# A guest says it's in the world (NetSession calls this once loaded).
func say_ready() -> void:
	if is_guest():
		for id in names:
			peer_joined.emit(id, names[id])
		send(&"ready", null, 1)

func on_peer_disconnected(id : int) -> void:
	if names.has(id):
		var who : String = names[id]
		names.erase(id)
		peer_left.emit(id, who)

# A guest's character goes to the host for the save.
func send_player_data() -> void:
	var player : Player = Player.find(get_tree())
	if is_guest() and player:
		send(&"player_data", SaveGame.player_data(player), 1)

#------------------------# Addresses and join codes

# A join code is the address and port packed into 10 letters, like
# "4KQ2-8M7X-ZD". Typing an address ("192.168.1.20" or "1.2.3.4:24680")
# works too.
static func encode_address(ip : String, port : int) -> String:
	var parts : PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return ""
	var value : int = 0
	for part in parts:
		value = (value << 8) | (int(part) & 255)
	value = (value << 16) | (port & 65535)
	var code : String = ""
	for i in 10:
		code = CODE_ALPHABET[value & 31] + code
		value >>= 5
	return code.substr(0, 4) + "-" + code.substr(4, 4) + "-" + code.substr(8)

static func decode_address(text : String) -> Array:
	var cleaned : String = text.strip_edges().to_upper()
	if cleaned.contains("."):
		var pieces : PackedStringArray = cleaned.split(":")
		var port : int = int(pieces[1]) if pieces.size() > 1 else PORT
		return [pieces[0], port] if pieces[0].is_valid_ip_address() else []
	cleaned = cleaned.replace("-", "").replace(" ", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if cleaned.length() != 10:
		return []
	var value : int = 0
	for letter in cleaned:
		var digit : int = CODE_ALPHABET.find(letter)
		if digit < 0:
			return []
		value = (value << 5) | digit
	var port : int = value & 65535
	value >>= 16
	var ip : String = "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
	return [ip, port]

static func lan_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and int(address.split(".")[1]) in range(16, 32)):
			return address
	return "127.0.0.1"

# Asks the router to forward the port (UPnP) on a thread, then makes the
# join code from the internet address it reports. Without UPnP only the
# local network code works.
func find_address(port : int) -> void:
	lanCode = encode_address(lan_address(), port)
	joinCode = lanCode
	addressNote = "Looking for your router..."
	if not ClassDB.class_exists("UPNP"):
		addressNote = "Only players on your network can join (same Wi-Fi)."
		address_ready.emit(joinCode, addressNote)
		return
	upnpThread = Thread.new()
	upnpThread.start(open_port.bind(port))

func open_port(port : int) -> void:
	var device : Object = ClassDB.instantiate("UPNP")
	var result : int = device.call("discover", 2000, 2, "InternetGatewayDevice")
	var external : String = ""
	var opened : bool = false
	if result == 0 and device.call("get_gateway") and device.call("get_gateway").call("is_valid_gateway"):
		opened = device.call("add_port_mapping", port, port, "Fishing Game", "UDP", 0) == 0
		external = device.call("query_external_address")
	finish_port.call_deferred(device, port, opened, external)

func finish_port(device : Object, port : int, opened : bool, external : String) -> void:
	if upnpThread:
		upnpThread.wait_to_finish()
		upnpThread = null
	if not is_host():
		if opened:
			device.call("delete_port_mapping", port, "UDP")
		return
	upnp = device
	if opened and external.is_valid_ip_address() and not private_address(external):
		mappedPort = port
		joinCode = encode_address(external, port)
		addressNote = "Share this code with your friend."
	elif opened:
		mappedPort = port
		addressNote = "Your internet provider shares one address between many homes (CGNAT), so only players on your network can join. Steam invites will get around this later."
	else:
		addressNote = "Your router didn't open the port by itself (UPnP is off), so only players on your network can join. Turn on UPnP in the router, or forward UDP port %d." % port
	address_ready.emit(joinCode, addressNote)

static func private_address(ip : String) -> bool:
	var parts : PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return true
	var a : int = int(parts[0])
	var b : int = int(parts[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b < 32) or (a == 100 and b >= 64 and b < 128)

func close_port() -> void:
	if upnp and mappedPort > 0:
		upnp.call("delete_port_mapping", mappedPort, "UDP")
	mappedPort = 0
	upnp = null
	joinCode = ""
	lanCode = ""

func _exit_tree() -> void:
	if upnpThread:
		upnpThread.wait_to_finish()
	close_port()
