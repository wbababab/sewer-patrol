class_name ScrapeCurseMoss extends JobBase
# Hold+wiggle minigame: alternate wiggle_left / wiggle_right inputs at the moss pulse rhythm.
# Any role can do it. Muckwarden gets a speed bonus.

const PROGRESS_PER_WIGGLE := 0.12
const DECAY_RATE := 0.04
const PULSE_INTERVAL := 0.6  # seconds between expected wiggles

var _last_wiggle: StringName = &""
var _pulse_timer: float = 0.0
var _holding: bool = false


func _ready() -> void:
	job_id = &"scrape_curse_moss"
	display_name = "Scrape Curse-Moss"
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	# Local visual pulse — no network needed
	_pulse_timer += delta
	if _prompt and fmod(_pulse_timer, PULSE_INTERVAL) < delta:
		_prompt.modulate = Color(0.8, 1.0, 0.6) if is_active else Color.WHITE


func tick(delta: float) -> void:
	# Check if any participating player is holding interact + wiggling
	var speed_bonus := 1.0
	for pid in participating_players:
		var player := GameManager.players.get(pid) as PlayerBase
		if player and player.role_data:
			speed_bonus = max(speed_bonus, player.get_job_speed_bonus(self))

	# Passive decay when not wiggling
	progress = max(0.0, progress - DECAY_RATE * delta)


# Called by the owning player's input on the host
func on_wiggle(direction: StringName, player_id: int) -> void:
	if not multiplayer.is_server() or is_complete:
		return
	if player_id not in participating_players:
		return
	if direction != _last_wiggle:
		_last_wiggle = direction
		var bonus := 1.0
		var player := GameManager.players.get(player_id) as PlayerBase
		if player:
			bonus = player.get_job_speed_bonus(self)
		progress = min(1.0, progress + PROGRESS_PER_WIGGLE * bonus)
