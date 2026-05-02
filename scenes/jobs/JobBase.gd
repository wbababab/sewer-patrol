class_name JobBase extends Node3D

signal job_completed(job_id: StringName, participants: Array)
signal player_joined_job(player_id: int)
signal player_left_job(player_id: int)

@export var job_id: StringName = &""
@export var display_name: String = ""
# StringNames of role IDs that can start this job (empty = any)
@export var required_roles: Array[StringName] = []
@export var min_players: int = 1

# Synchronized via MultiplayerSynchronizer
var progress: float = 0.0
var is_active: bool = false
var is_complete: bool = false
var participating_players: Array = []

@onready var _prompt: Label3D = $PromptLabel
@onready var _progress_bar: Node3D = $ProgressBar


func _ready() -> void:
	add_to_group("jobs")
	if multiplayer.is_server():
		var area: Area3D = get_node_or_null("InteractZone")
		if area:
			area.body_entered.connect(_on_body_entered)
			area.body_exited.connect(_on_body_exited)
	_update_prompt()


# Called by PlayerBase._try_interact()
func can_interact(player: PlayerBase) -> bool:
	if is_complete:
		return false
	if required_roles.is_empty():
		return true
	var role_id := player.role_data.role_id if player.role_data else &""
	return role_id in required_roles


func start_or_join(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	if is_complete or player_id in participating_players:
		return
	if participating_players.size() >= 4:
		return
	participating_players.append(player_id)
	is_active = true
	player_joined_job.emit(player_id)
	_on_player_joined(player_id)


func leave_job(player_id: int) -> void:
	participating_players.erase(player_id)
	if participating_players.is_empty():
		is_active = false
	player_left_job.emit(player_id)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not is_active or is_complete:
		return
	tick(delta)
	if progress >= 1.0:
		_complete()


# Override in subclasses
func tick(_delta: float) -> void:
	pass


func _on_player_joined(_player_id: int) -> void:
	pass


func _complete() -> void:
	is_complete = true
	is_active = false
	progress = 1.0
	_play_complete_fx.rpc()
	job_completed.emit(job_id, participating_players)
	GameManager.on_job_completed(job_id)


@rpc("authority", "call_local", "reliable")
func _play_complete_fx() -> void:
	if _prompt:
		_prompt.text = "DONE"
		_prompt.modulate = Color(0.5, 1.0, 0.5)


func _update_prompt() -> void:
	if _prompt == null:
		return
	if is_complete:
		_prompt.text = "Done"
	elif required_roles.is_empty():
		_prompt.text = "[E] " + display_name
	else:
		_prompt.text = "[E] " + display_name + "\n(" + " / ".join(required_roles) + ")"


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_update_prompt()


func _on_body_exited(_body: Node3D) -> void:
	pass


# ── Client→Server RPC bridges ─────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func request_join(peer_id: int) -> void:
	if multiplayer.is_server():
		start_or_join(peer_id)

@rpc("any_peer", "reliable")
func request_press(peer_id: int) -> void:
	if multiplayer.is_server():
		_handle_press(peer_id)

@rpc("any_peer", "unreliable")
func request_wiggle(peer_id: int, direction: StringName) -> void:
	if multiplayer.is_server():
		_handle_wiggle(peer_id, direction)

# Override in subclasses that need active button interaction
func _handle_press(_peer_id: int) -> void:
	pass

# Override in subclasses that need wiggle input
func _handle_wiggle(_peer_id: int, _direction: StringName) -> void:
	pass
