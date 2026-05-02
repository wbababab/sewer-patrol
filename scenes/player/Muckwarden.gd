class_name Muckwarden extends PlayerBase

const CHARGE_SPEED := 12.0
const CHARGE_DURATION := 0.4
const CHARGE_STAGGER_RADIUS := 2.5

var _charging: bool = false
var _charge_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if _charging:
		_charge_timer -= delta
		# Drive forward at charge speed, overriding normal movement
		var forward := -_mesh.global_transform.basis.z
		velocity.x = forward.x * CHARGE_SPEED
		velocity.z = forward.z * CHARGE_SPEED
		move_and_slide()
		if _charge_timer <= 0.0:
			_charging = false
			_check_stagger()
		return
	super(delta)


func use_special_ability() -> void:
	if _charging:
		return
	_charging = true
	_charge_timer = CHARGE_DURATION
	current_state = &"charging"


func get_job_speed_bonus(job: Node) -> float:
	# Muckwarden is faster at physical jobs
	var physical_tags: Array[StringName] = [&"scrape_curse_moss", &"unclog_privy_channel"]
	for tag in physical_tags:
		if job.get("job_id") == tag:
			return 1.3
	return 1.0


func _check_stagger() -> void:
	var bodies: Array[Node3D] = ($InteractArea as Area3D).get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("players") and body != self:
			var dist := global_position.distance_to(body.global_position)
			if dist < CHARGE_STAGGER_RADIUS:
				# Friendly stagger — knocks them back slightly (intended comedy)
				if body.has_method("apply_knockback"):
					body.apply_knockback((body.global_position - global_position).normalized() * 5.0)
