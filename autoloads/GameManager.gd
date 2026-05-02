extends Node

signal game_state_changed(new_state: State)
signal job_completed(job_id: StringName)
signal level_ready()
signal run_finished(report: Dictionary)

enum State { LOBBY, LOADING, PLAYING, FINISHED }

var game_state := State.LOBBY
# role StringName -> peer_id
var player_roles: Dictionary = {}
# peer_id -> player node
var players: Dictionary = {}
# job_id -> JobBase node
var active_jobs: Dictionary = {}
var completed_jobs: Array[StringName] = []
var required_jobs: int = 0
var level_data: Dictionary = {}

const LEVEL_SCENE := "res://scenes/world/SewerLevel.tscn"


func _ready() -> void:
	NetworkManager.all_peers_ready.connect(_on_all_peers_ready)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)


# ── Host-only: start a run ────────────────────────────────────────────────────

func start_run(roles: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	player_roles = roles
	_set_state(State.LOADING)
	var seed_val := randi()
	_load_level.rpc(seed_val, roles)


@rpc("authority", "call_local", "reliable")
func _load_level(seed_val: int, roles: Dictionary) -> void:
	player_roles = roles
	level_data = {"seed": seed_val}
	get_tree().change_scene_to_file(LEVEL_SCENE)
	await get_tree().process_frame
	level_ready.emit()


# Called by SewerLevel after it finishes placing jobs
func register_jobs(job_ids: Array[StringName], required_count: int) -> void:
	completed_jobs.clear()
	required_jobs = required_count
	for id in job_ids:
		active_jobs[id] = null  # node refs filled by JobBase._ready()


func register_job_node(job_id: StringName, node: Node) -> void:
	active_jobs[job_id] = node


func on_job_completed(job_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	if job_id in completed_jobs:
		return
	completed_jobs.append(job_id)
	_notify_job_complete.rpc(job_id)
	if completed_jobs.size() >= required_jobs:
		_unlock_exit.rpc()


@rpc("authority", "call_local", "reliable")
func _notify_job_complete(job_id: StringName) -> void:
	job_completed.emit(job_id)


@rpc("authority", "call_local", "reliable")
func _unlock_exit() -> void:
	get_tree().get_first_node_in_group("exit_door").unlock()


func finish_run() -> void:
	if not multiplayer.is_server():
		return
	var report := {
		"jobs_done": completed_jobs.size(),
		"jobs_required": required_jobs,
	}
	_end_run.rpc(report)


@rpc("authority", "call_local", "reliable")
func _end_run(report: Dictionary) -> void:
	_set_state(State.FINISHED)
	run_finished.emit(report)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_state(s: State) -> void:
	game_state = s
	game_state_changed.emit(s)


func _on_all_peers_ready() -> void:
	if multiplayer.is_server() and game_state == State.LOBBY:
		pass  # Host waits for explicit start_run() call from UI


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
