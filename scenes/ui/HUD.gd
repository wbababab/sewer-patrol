extends CanvasLayer

@onready var _job_list: VBoxContainer = $HUDRoot/JobPanel/JobList
@onready var _health_bar: ProgressBar = $HUDRoot/HealthBar
@onready var _room_code_label: Label = $HUDRoot/RoomCode
@onready var _exit_hint: Label = $HUDRoot/ExitHint

var _local_player: PlayerBase = null


func _ready() -> void:
	GameManager.job_completed.connect(_on_job_completed)
	GameManager.run_finished.connect(_on_run_finished)
	_room_code_label.text = NetworkManager.room_code
	_exit_hint.visible = false

	# Jobs are registered in SewerLevel._ready() which runs after HUD._ready();
	# wait one frame so the job list is populated before building the UI.
	await get_tree().process_frame
	_rebuild_job_list()
	_local_player = GameManager.players.get(multiplayer.get_unique_id()) as PlayerBase


func _process(_delta: float) -> void:
	if _local_player:
		_health_bar.value = _local_player.health
		_health_bar.max_value = _local_player.role_data.max_health if _local_player.role_data else 100


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

	if GameManager.completed_jobs.size() >= GameManager.required_jobs:
		_exit_hint.visible = true
		_exit_hint.text = "Exit unlocked — head to the surface!"


func _on_run_finished(report: Dictionary) -> void:
	var label := Label.new()
	label.text = "Run complete! Jobs: %d/%d" % [report.jobs_done, report.jobs_required]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUDRoot.add_child(label)
