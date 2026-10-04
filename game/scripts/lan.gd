extends Node
## Hotspot / Wi-Fi play without any internet server.
## The host phone runs a tiny WebSocket relay inside the game (same messages as relay/server.js)
## and shouts "I'm here" on UDP every second. Phones on the same hotspot listen for that
## shout and list the games they hear. Everyone, including the host itself, then talks to the
## relay through Net, exactly like the online version.

signal found_changed

const PORT := 8787
const DISCOVERY_PORT := 8788
const MAX_PLAYERS := 4

# --- host side ---
var hosting := false
var host_name := ""
var _server: TCPServer
var _peers := []  # {ws, id, name, color}
var _next_id := 1
var _host_id := 0
var _udp_out: PacketPeerUDP
var _announce_t := 0.0

# --- joiner side ---
var listening := false
var found := {}  # ip -> {name, players, seen}
var _udp_in: PacketPeerUDP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## IPv4 addresses on this device's local networks (hotspot / Wi-Fi), e.g. 192.168.43.1
func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31):
			out.append(ip)
	return out


# ---------- hosting ----------

func start_host(pname: String) -> bool:
	stop_host()
	_server = TCPServer.new()
	if _server.listen(PORT, "*") != OK:
		_server = null
		return false
	host_name = pname
	hosting = true
	_next_id = 1
	_host_id = 0
	_peers.clear()
	_udp_out = PacketPeerUDP.new()
	_udp_out.set_broadcast_enabled(true)
	_announce_t = 0.0
	return true


func stop_host() -> void:
	for p in _peers:
		(p["ws"] as WebSocketPeer).close()
	_peers.clear()
	if _server:
		_server.stop()
	_server = null
	if _udp_out:
		_udp_out.close()
	_udp_out = null
	hosting = false


func _joined() -> Array:
	return _peers.filter(func(p): return int(p["id"]) > 0)


func _send(p: Dictionary, m: Dictionary) -> void:
	var ws: WebSocketPeer = p["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(m))


func _bcast(m: Dictionary, except_id: int) -> void:
	var txt := JSON.stringify(m)
	var is_state := str(m.get("t", "")) == "st"
	for p in _peers:
		if int(p["id"]) > 0 and int(p["id"]) != except_id:
			var ws: WebSocketPeer = p["ws"]
			if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
				# a phone that's fallen behind doesn't need a backlog of old positions,
				# only the newest ones; everything else (events) always goes through
				if is_state and ws.get_current_outbound_buffered_amount() > 32768:
					continue
				ws.send_text(txt)


func _serve() -> void:
	while _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 20
		ws.outbound_buffer_size = 1 << 20
		var tcp := _server.take_connection()
		tcp.set_no_delay(true)   # no Nagle bundling: positions go out the moment they're sent
		if ws.accept_stream(tcp) == OK:
			_peers.append({"ws": ws, "id": 0, "name": "", "color": 0})
	for p in _peers.duplicate():
		var ws: WebSocketPeer = p["ws"]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if m is Dictionary:
					_on_msg(p, m)
		elif st == WebSocketPeer.STATE_CLOSED:
			_peers.erase(p)
			var pid := int(p["id"])
			if pid > 0:
				_bcast({"t": "peer_leave", "id": pid}, -1)
				if pid == _host_id and not _joined().is_empty():
					_host_id = int(_joined()[0]["id"])
					_bcast({"t": "host", "id": _host_id}, -1)


func _on_msg(p: Dictionary, m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	if int(p["id"]) == 0:
		if t != "create" and t != "join":
			return
		if _joined().size() >= MAX_PLAYERS:
			_send(p, {"t": "error", "msg": "This game is full (4 players max)."})
			return
		p["id"] = _next_id
		_next_id += 1
		p["name"] = str(m.get("name", "Player")).substr(0, 14)
		p["color"] = clampi(int(m.get("color", 0)), 0, 15)
		if _host_id == 0:
			_host_id = int(p["id"])
		var players := []
		for q in _joined():
			players.append({"id": q["id"], "name": q["name"], "color": q["color"]})
		_send(p, {"t": "welcome", "id": p["id"], "room": "LAN", "host": _host_id, "players": players})
		_bcast({"t": "peer_join", "id": p["id"], "name": p["name"], "color": p["color"]}, int(p["id"]))
		return
	if t == "ping":
		_send(p, {"t": "pong"})
		return
	m["from"] = p["id"]
	if m.has("to"):
		for q in _peers:
			if int(q["id"]) == int(m["to"]):
				_send(q, m)
		return
	_bcast(m, int(p["id"]))


func _announce() -> void:
	var msg := JSON.stringify({"game": "peekaboo", "v": 1, "name": host_name, "port": PORT, "players": _joined().size()}).to_utf8_buffer()
	var targets := ["255.255.255.255", "127.0.0.1"]
	for ip in local_ips():
		var parts: PackedStringArray = ip.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for t in targets:
		_udp_out.set_dest_address(t, DISCOVERY_PORT)
		_udp_out.put_packet(msg)


# ---------- finding games ----------

func start_listening() -> bool:
	stop_listening()
	_udp_in = PacketPeerUDP.new()
	if _udp_in.bind(DISCOVERY_PORT, "*") != OK:
		_udp_in = null
		return false
	listening = true
	found.clear()
	return true


func stop_listening() -> void:
	if _udp_in:
		_udp_in.close()
	_udp_in = null
	listening = false


func _listen() -> void:
	var changed := false
	while _udp_in.get_available_packet_count() > 0:
		var pkt := _udp_in.get_packet()
		var ip := _udp_in.get_packet_ip()
		var m = JSON.parse_string(pkt.get_string_from_utf8())
		if m is Dictionary and m.get("game", "") == "peekaboo":
			if ip == "127.0.0.1":
				# our own machine (testing on one PC): only use it if nothing better turns up
				pass
			if not found.has(ip):
				changed = true
			found[ip] = {"name": str(m.get("name", "?")), "players": int(m.get("players", 1)), "port": int(m.get("port", PORT)), "seen": Time.get_ticks_msec()}
	var now := Time.get_ticks_msec()
	for ip in found.keys():
		if now - int(found[ip]["seen"]) > 4000:
			found.erase(ip)
			changed = true
	if changed:
		found_changed.emit()


func _process(dt: float) -> void:
	if hosting and _server:
		_serve()
		_announce_t -= dt
		if _announce_t <= 0.0:
			_announce_t = 1.0
			_announce()
	if listening and _udp_in:
		_listen()
