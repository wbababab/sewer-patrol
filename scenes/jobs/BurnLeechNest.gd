class_name BurnLeechNest extends JobBase
# Lantern Friar channels Ward Chant near the nest.
# Progress advances while a Friar is chanting (friar_chanting meta set by LanternFriar.gd).
# Other players standing in the ASSIST_RADIUS speed things up.

const CHANNEL_RATE := 0.15
const ASSIST_RATE := 0.04
const ASSIST_RADIUS := 3.5
const INTERRUPT_CHANCE := 0.008  # per physics frame, when chanting without assist


func _ready() -> void:
	job_id = &"burn_leech_nest"
	display_name = "Burn Leech Nest"
	required_roles = [&"lantern_friar"]
	super()


func tick(delta: float) -> void:
	var friar_chanting := get_meta("friar_chanting", false) as bool
	if not friar_chanting:
		return

	var base_rate := CHANNEL_RATE
	var assistants := _count_assistants()

	# Random interruption without assistants
	if assistants == 0 and randf() < INTERRUPT_CHANCE:
		_on_interrupt.rpc()
		return

	var assist_bonus := assistants * ASSIST_RATE
	progress = min(1.0, progress + (base_rate + assist_bonus) * delta)


func _count_assistants() -> int:
	var count := 0
	for pid in participating_players:
		var player := GameManager.players.get(pid) as PlayerBase
		if player == null:
			continue
		if player.role_data and player.role_data.role_id == &"lantern_friar":
			continue  # Friar doesn't count as their own assistant
		if global_position.distance_to(player.global_position) < ASSIST_RADIUS:
			count += 1
	return count


@rpc("authority", "call_local", "reliable")
func _on_interrupt() -> void:
	if _prompt:
		_prompt.text = "INTERRUPTED!"
		_prompt.modulate = Color(1.0, 0.4, 0.4)
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(func(): _update_prompt(); _prompt.modulate = Color.WHITE)
