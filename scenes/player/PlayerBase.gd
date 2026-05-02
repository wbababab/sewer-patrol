class_name PlayerBase extends CharacterBody3D

const GRAVITY := 20.0
const JUMP_VELOCITY := 5.0

@export var role_data: PlayerRoleData

# Synchronized state
var health: int = 100
var stamina: float = 1.0
var current_state: StringName = &"idle"

var _special_timer: float = 0.0
var _nearby_jobs: Array = []

@onready var _camera_arm: SpringArm3D = $CameraArm
@onready var _camera: Camera3D = $CameraArm/Camera3D
@onready var _mesh: Node3D = $Mesh
@onready var _interact_area: Area3D = $InteractArea
@onready var _name_label: Label3D = $NameLabel
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer


func _ready() -> void:
	collision_layer = 2  # jobs' InteractZone masks for layer 2
	var is_mine := is_multiplayer_authority()
	_camera.current = is_mine
	set_physics_process(is_mine)

	if is_mine:
		# Job InteractZones are Area3D, not physics bodies — use area_entered
		_interact_area.area_entered.connect(_on_job_zone_entered)
		_interact_area.area_exited.connect(_on_job_zone_exited)

	if role_data:
		health = role_data.max_health
		_name_label.text = _get_role_display()
		_apply_role_color()

	add_to_group("players")


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var move_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var speed := role_data.move_speed if role_data else 4.0

	# Orient movement to camera yaw
	var cam_basis := Basis(Vector3.UP, _camera_arm.global_rotation.y)
	var wish_dir := cam_basis * Vector3(move_dir.x, 0, move_dir.y)
	velocity.x = wish_dir.x * speed
	velocity.z = wish_dir.z * speed

	# Rotate mesh to face movement
	if wish_dir.length() > 0.1:
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, atan2(wish_dir.x, wish_dir.z), 12.0 * delta)

	move_and_slide()

	# Camera orbit (Q = rotate left, R = rotate right)
	var cam_turn := Input.get_axis("cam_left", "cam_right")
	_camera_arm.rotation.y -= cam_turn * 2.0 * delta

	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# Wiggle inputs — forwarded to active job
	if Input.is_action_just_pressed("wiggle_left"):
		_forward_wiggle(&"left")
	if Input.is_action_just_pressed("wiggle_right"):
		_forward_wiggle(&"right")

	# Special ability
	_special_timer = max(0.0, _special_timer - delta)
	if Input.is_action_just_pressed("special") and _special_timer <= 0.0:
		use_special_ability()
		_special_timer = role_data.special_cooldown if role_data else 8.0

	current_state = &"moving" if wish_dir.length() > 0.1 else &"idle"


func _try_interact() -> void:
	if _nearby_jobs.is_empty():
		return
	var job := _nearby_jobs[0] as JobBase
	if not job.can_interact(self):
		return
	var pid := get_multiplayer_authority()
	if pid not in job.participating_players:
		if multiplayer.is_server():
			job.start_or_join(pid)
		else:
			job.request_join.rpc_id(1, pid)
	else:
		if multiplayer.is_server():
			job._handle_press(pid)
		else:
			job.request_press.rpc_id(1, pid)


func _forward_wiggle(direction: StringName) -> void:
	var pid := get_multiplayer_authority()
	for job: JobBase in _nearby_jobs:
		if pid in job.participating_players:
			if multiplayer.is_server():
				job._handle_wiggle(pid, direction)
			else:
				job.request_wiggle.rpc_id(1, pid, direction)
			break


func _on_job_zone_entered(area: Area3D) -> void:
	var job := area.get_parent()
	if job and job.is_in_group("jobs"):
		_nearby_jobs.append(job)


func _on_job_zone_exited(area: Area3D) -> void:
	var job := area.get_parent()
	_nearby_jobs.erase(job)


# ── Role hooks (override in subclasses) ───────────────────────────────────────

func use_special_ability() -> void:
	pass


func get_job_speed_bonus(_job: Node) -> float:
	return 1.0


func get_debrief_stats() -> Dictionary:
	return {}


func _get_role_display() -> String:
	return role_data.display_name if role_data else "Cesswarden"


func _apply_role_color() -> void:
	var mesh_inst := _mesh.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst or not role_data:
		return
	var mat := mesh_inst.get_surface_override_material(0)
	if mat:
		var unique_mat := mat.duplicate() as ShaderMaterial
		unique_mat.set_shader_parameter("albedo_tint", role_data.role_color)
		mesh_inst.set_surface_override_material(0, unique_mat)


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse


# ── Health ────────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
	health = max(0, health - amount)
	if health == 0:
		current_state = &"downed"
