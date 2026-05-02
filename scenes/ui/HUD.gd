extends CanvasLayer

@onready var _job_list: VBoxContainer = $HUDRoot/JobPanel/JobList
@onready var _health_bar: ProgressBar = $HUDRoot/HealthBar
@onready var _room_code_label: Label = $HUDRoot/RoomCode
@onready var _exit_hint: Label = $HUDRoot/ExitHint


func _ready() -> void:
	GameManager.job_completed.connect(_on_job_completed)
	GameManager.run_finished.connect(_on_run_finished)
	_room_code_label.text = NetworkManager.room_code
	_exit_hint.visible = false

	# Build initial job tracker from active jobs
	await get_tree().process_frame
	_rebuild_job_list()

	# Connect local player health
	var local_player: PlayerBase = GameManager.players.get(multiplayer.get_unique_id())
	if local_player:
		local_player.property_list_changed.connect(_update_health)


func _rebuild_job_list() -> void:
	for child in _job_list.get_children():
		child.queue_free()
	for job_id in GameManager.active_jobs:
		var row := HBoxContainer.new()
		var icon := Label.new()
		icon.text = "[ ]"
		icon.name = "Icon_" + str(job_id)
		icon.custom_minimum_size = Vector2(30, 0)
		var lbl := Label.new()
		lbl.text = str(job_id).replace("_", " ").capitalize()
		row.add_child(icon)
		row.add_child(lbl)
		_job_list.add_child(row)


func _on_job_completed(job_id: StringName) -> void:
	var icon := _job_list.find_child("Icon_" + str(job_id), true, false) as Label
	if icon:
		icon.text = "[x]"
		icon.modulate = Color(0.5, 1.0, 0.5)

	# Check if exit is now available
	if GameManager.completed_jobs.size() >= GameManager.required_jobs:
		_exit_hint.visible = true
		_exit_hint.text = "Exit unlocked — head to the surface!"


func _update_health() -> void:
	var player := GameManager.players.get(multiplayer.get_unique_id()) as PlayerBase
	if player:
		_health_bar.value = player.health
		_health_bar.max_value = player.role_data.max_health if player.role_data else 100


func _on_run_finished(report: Dictionary) -> void:
	var label := Label.new()
	label.text = "Run complete! Jobs: %d/%d" % [report.jobs_done, report.jobs_required]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUDRoot.add_child(label)
