class_name RatCatcher extends PlayerBase

const MAX_TRAPS := 2

var _active_traps: int = 0
var _scouting_timer: float = 0.0
const SCOUT_REVEAL_TIME := 2.0


func _physics_process(delta: float) -> void:
	super(delta)

	# Scout reveal: standing still for 2s reveals nearby job nodes on minimap
	if velocity.length() < 0.5:
		_scouting_timer += delta
		if _scouting_timer >= SCOUT_REVEAL_TIME:
			_reveal_nearby_jobs()
			_scouting_timer = 0.0
	else:
		_scouting_timer = 0.0


func use_special_ability() -> void:
	if _active_traps >= MAX_TRAPS:
		return
	_deploy_trap()


func _deploy_trap() -> void:
	var trap_scene: PackedScene = load("res://scenes/props/rat_trap.tscn")
	if trap_scene == null:
		return
	var trap: Node3D = trap_scene.instantiate()
	trap.global_position = global_position
	get_tree().current_scene.add_child(trap)
	_active_traps += 1
	trap.tree_exiting.connect(func(): _active_traps -= 1)


func get_job_speed_bonus(job: Node) -> float:
	# Rat-Catcher has exclusive access to bell-resetting
	if job.get("job_id") == &"reset_rat_bells":
		return 1.0
	return 0.8  # Slightly slower on physical brute-force jobs


func _reveal_nearby_jobs() -> void:
	for job in get_tree().get_nodes_in_group("jobs"):
		var dist := global_position.distance_to(job.global_position)
		if dist < 15.0:
			job.set_meta("minimap_visible", true)
