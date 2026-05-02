extends Node

# Signals for the rest of the game to react to
signal room_created(code: String)
signal room_joined(code: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed(reason: String)
signal all_peers_ready()

const SIGNAL_SERVER := "ws://localhost:8765"
const STUN_SERVERS := [{"urls": ["stun:stun.l.google.com:19302"]}]

enum State { DISCONNECTED, SIGNALING, CONNECTING, CONNECTED }

var state := State.DISCONNECTED
var local_peer_id: int = 0
var is_host: bool = false
var room_code: String = ""

var _ws := WebSocketPeer.new()
var _rtc := WebRTCMultiplayerPeer.new()
# peer_id -> WebRTCPeerConnection
var _connections: Dictionary = {}
var _ready_peers: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if state == State.SIGNALING:
		_ws.poll()
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			_handle_signal_message(JSON.parse_string(pkt.get_string_from_utf8()))


# ── Public API ────────────────────────────────────────────────────────────────

func create_room() -> void:
	is_host = true
	_connect_to_signal_server()
	await _ws_open()
	_ws_send({"type": "create_room"})


func join_room(code: String) -> void:
	is_host = false
	room_code = code.to_upper()
	_connect_to_signal_server()
	await _ws_open()
	_ws_send({"type": "join_room", "room": room_code})


func signal_ready() -> void:
	_ws_send({"type": "ready"})


func disconnect_from_room() -> void:
	_ws.close()
	_rtc.close()
	multiplayer.multiplayer_peer = null
	state = State.DISCONNECTED
	_connections.clear()
	_ready_peers.clear()
	local_peer_id = 0


# ── Signaling ─────────────────────────────────────────────────────────────────

func _connect_to_signal_server() -> void:
	_ws = WebSocketPeer.new()
	state = State.SIGNALING
	var err := _ws.connect_to_url(SIGNAL_SERVER)
	if err != OK:
		connection_failed.emit("Cannot reach signaling server")
		state = State.DISCONNECTED


func _ws_open() -> Signal:
	while _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_ws.poll()
		await get_tree().process_frame
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connection_failed.emit("Signaling server connection failed")
	return _ws.message_received if false else get_tree().process_frame  # dummy; caller uses await


func _ws_send(obj: Dictionary) -> void:
	_ws.send_text(JSON.stringify(obj))


func _handle_signal_message(msg: Dictionary) -> void:
	if msg == null:
		return
	match msg.get("type", ""):
		"room_created":
			local_peer_id = msg.your_id
			room_code = msg.room
			_init_rtc_host()
			room_created.emit(room_code)
		"room_joined":
			local_peer_id = msg.your_id
			room_code = msg.room
			_init_rtc_mesh()
			# Initiate a connection to every existing peer
			for pid in msg.peers:
				_create_peer_connection(pid, true)
		"peer_joined":
			_create_peer_connection(msg.peer_id, false)
		"peer_left":
			_connections.erase(msg.peer_id)
			peer_disconnected.emit(msg.peer_id)
		"offer":
			_handle_offer(msg.from, msg.sdp)
		"answer":
			_handle_answer(msg.from, msg.sdp)
		"ice":
			_handle_ice(msg.from, msg.media, msg.index, msg.name)
		"peer_ready":
			_ready_peers.append(msg.peer_id)
			if _rtc.get_peers().size() > 0 and _ready_peers.size() >= _rtc.get_peers().size():
				all_peers_ready.emit()
		"room_full":
			connection_failed.emit("Room is full (max 4 players)")
		"error":
			connection_failed.emit(msg.get("message", "Unknown error"))


# ── WebRTC setup ──────────────────────────────────────────────────────────────

func _init_rtc_host() -> void:
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	state = State.CONNECTED
	room_joined.emit(room_code)


func _init_rtc_mesh() -> void:
	_rtc.create_mesh(local_peer_id)
	multiplayer.multiplayer_peer = _rtc
	state = State.CONNECTING


func _create_peer_connection(peer_id: int, polite: bool) -> void:
	var conn := WebRTCPeerConnection.new()
	conn.initialize({"iceServers": STUN_SERVERS})
	_connections[peer_id] = conn
	_rtc.add_peer(conn, peer_id)

	conn.session_description_created.connect(func(type, sdp):
		conn.set_local_description(type, sdp)
		_ws_send({"type": type, "to": peer_id, "sdp": sdp})
	)
	conn.ice_candidate_created.connect(func(media, index, cand_name):
		_ws_send({"type": "ice", "to": peer_id, "media": media, "index": index, "name": cand_name})
	)

	if polite:
		conn.create_offer()


func _handle_offer(from: int, sdp: String) -> void:
	var conn: WebRTCPeerConnection = _connections.get(from)
	if conn == null:
		_create_peer_connection(from, false)
		conn = _connections[from]
	conn.set_remote_description("offer", sdp)


func _handle_answer(from: int, sdp: String) -> void:
	var conn: WebRTCPeerConnection = _connections.get(from)
	if conn:
		conn.set_remote_description("answer", sdp)


func _handle_ice(from: int, media: String, index: int, cand_name: String) -> void:
	var conn: WebRTCPeerConnection = _connections.get(from)
	if conn:
		conn.add_ice_candidate(media, index, cand_name)


func _on_peer_connected(id: int) -> void:
	state = State.CONNECTED
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_connections.erase(id)
	peer_disconnected.emit(id)
