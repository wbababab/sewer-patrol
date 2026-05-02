extends Control

@onready var _host_btn: Button = $VBox/HostButton
@onready var _join_btn: Button = $VBox/JoinButton
@onready var _code_field: LineEdit = $VBox/CodeField
@onready var _status_label: Label = $VBox/StatusLabel


func _ready() -> void:
	_host_btn.pressed.connect(_on_host)
	_join_btn.pressed.connect(_on_join)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.connection_failed.connect(_on_fail)


func _on_host() -> void:
	_status_label.text = "Creating room..."
	_host_btn.disabled = true
	_join_btn.disabled = true
	NetworkManager.create_room()


func _on_join() -> void:
	var code := _code_field.text.strip_edges().to_upper()
	if code.length() != 4:
		_status_label.text = "Enter a 4-letter room code."
		return
	_status_label.text = "Joining %s..." % code
	_join_btn.disabled = true
	NetworkManager.join_room(code)


func _on_room_created(code: String) -> void:
	_status_label.text = "Room created: %s\nWaiting for players..." % code
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")


func _on_room_joined(_code: String) -> void:
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")


func _on_fail(reason: String) -> void:
	_status_label.text = "Failed: " + reason
	_host_btn.disabled = false
	_join_btn.disabled = false
