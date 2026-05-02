class_name LanternFriar extends PlayerBase

const CHANT_DURATION := 4.0
const CHANT_RADIUS := 6.0
const MAX_CHANTS_PER_RUN := 3

var _chanting: bool = false
var _chant_timer: float = 0.0
var _chant_count: int = 0

@onready var _lantern_light: OmniLight3D = $Mesh/LanternLight


func _physics_process(delta: float) -> void:
	super(delta)

	if _chanting:
		_chant_timer -= delta
		current_state = &"chanting"
		if _chant_timer <= 0.0:
			_end_chant()


func use_special_ability() -> void:
	if _chanting or _chant_count >= MAX_CHANTS_PER_RUN:
		return
	_start_chant()


func _start_chant() -> void:
	_chanting = true
	_chant_timer = CHANT_DURATION
	_chant_count += 1
	current_state = &"chanting"
	_apply_ward_effect()


func _end_chant() -> void:
	_chanting = false
	current_state = &"idle"


func _apply_ward_effect() -> void:
	# Suppress/damage anything in "undead" group within radius
	for body in get_tree().get_nodes_in_group("undead"):
		if global_position.distance_to(body.global_position) < CHANT_RADIUS:
			if body.has_method("on_ward"):
				body.on_ward()

	# Speed up nearby BurnLeechNest jobs
	for job in get_tree().get_nodes_in_group("jobs"):
		if job.get("job_id") == &"burn_leech_nest":
			if global_position.distance_to(job.global_position) < CHANT_RADIUS:
				job.set_meta("friar_chanting", true)

	# Schedule clearing the chant boost flag
	var tween := create_tween()
	tween.tween_interval(CHANT_DURATION)
	tween.tween_callback(func():
		for job in get_tree().get_nodes_in_group("jobs"):
			job.remove_meta("friar_chanting") if job.has_meta("friar_chanting") else null
	)


func get_job_speed_bonus(job: Node) -> float:
	if job.get("job_id") == &"burn_leech_nest":
		return 1.5
	return 1.0


func _get_role_display() -> String:
	return "Lantern Friar"
