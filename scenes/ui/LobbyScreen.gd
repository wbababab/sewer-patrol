extends Control

const ROLES := [
	{"id": &"muckwarden",    "name": "Muckwarden",    "desc": "Brute force. Gets stuck in sludge. Saves others."},
	{"id": &"rat_catcher",   "name": "Rat-Catcher",   "desc": "Fast. Traps and tunnels. Can parley with rats."},
	{"id": &"lantern_friar", "name": "Lantern Friar", "desc": "Ward chants. Disease control. Anti-undead."},
]

var _selected_role: StringName = &"muckwarden"

@onready var _room_code_label: Label = $Panel/VBox/RoomCodeLabel
@onready var _player_list: VBoxContainer = $Panel/VBox/PlayerList
@onready var _role_buttons: HBoxContainer = $Panel/VBox/RoleButtons
@onready var _role_desc: Label = $Panel/VBox/RoleDesc
@onready var _ready_btn: Button = $Panel/VBox/ReadyButton
@onready var _start_btn: Button = $Panel/VBox/StartButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_room_code_label.text = "Room: %s" % NetworkManager.room_code

	_ready_btn.pressed.connect(_on_ready)
	_start_btn.pressed.connect(_on_start)
	_start_btn.visible = NetworkManager.is_host

	NetworkManager.peer_connected.connect(_refresh_player_list)
	NetworkManager.peer_disconnected.connect(_refresh_player_list)
	GameManager.game_state_changed.connect(_on_game_state)

	_build_role_buttons()
	_refresh_player_list(0)


func _build_role_buttons() -> void:
	for child in _role_buttons.get_children():
		child.queue_free()
	for role in ROLES:
		var btn := Button.new()
		btn.text = role.name
		btn.toggle_mode = true
		btn.button_pressed = (role.id == _selected_role)
		btn.pressed.connect(func(): _select_role(role.id, role.desc))
		_role_buttons.add_child(btn)


func _select_role(role_id: StringName, desc: String) -> void:
	_selected_role = role_id
	_role_desc.text = desc
	# Deselect other buttons
	for btn in _role_buttons.get_children():
		btn.button_pressed = (btn.text == _get_role_name(role_id))


func _get_role_name(role_id: StringName) -> String:
	for r in ROLES:
		if r.id == role_id:
			return r.name
	return ""


func _refresh_player_list(_id: int) -> void:
	for child in _player_list.get_children():
		child.queue_free()
	var peers := multiplayer.get_peers()
	peers.append(multiplayer.get_unique_id())
	for pid in peers:
		var lbl := Label.new()
		lbl.text = "Player %d%s" % [pid, " (you)" if pid == multiplayer.get_unique_id() else ""]
		_player_list.add_child(lbl)


func _on_ready() -> void:
	_ready_btn.disabled = true
	NetworkManager.signal_ready()
	var pid := multiplayer.get_unique_id()
	if multiplayer.is_server():
		GameManager.player_roles[pid] = _selected_role
	else:
		_register_role.rpc_id(1, pid, _selected_role)


@rpc("any_peer", "reliable")
func _register_role(peer_id: int, role_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	GameManager.player_roles[peer_id] = role_id


func _on_start() -> void:
	if not NetworkManager.is_host:
		return
	# Ensure host's role is registered even if they skipped READY
	var pid := multiplayer.get_unique_id()
	if pid not in GameManager.player_roles:
		GameManager.player_roles[pid] = _selected_role
	GameManager.start_run(GameManager.player_roles)


func _on_game_state(state: GameManager.State) -> void:
	if state == GameManager.State.LOADING:
		pass  # Scene change handled by GameManager RPC
