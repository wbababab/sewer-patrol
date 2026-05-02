class_name UnclogPrivyChannel extends JobBase
# 2-player timing minigame: both players must hit the green zone within 0.5s of each other.
# A bar cycles from 0->1->0 continuously. Hitting interact sets your "ready" timestamp.
# If both ready timestamps are within SYNC_WINDOW, award a big progress burst.

const SYNC_WINDOW := 0.5
const BURST_PROGRESS := 0.35
const SMALL_PROGRESS := 0.08
const CYCLE_SPEED := 0.8       # bar cycles per second
const GREEN_ZONE_LOW := 0.4
const GREEN_ZONE_HIGH := 0.65

var _bar_phase: float = 0.0    # 0.0 - 1.0 oscillating
var _bar_dir: int = 1
# peer_id -> timestamp of their last "ready" press
var _ready_timestamps: Dictionary = {}


func _ready() -> void:
	job_id = &"unclog_privy_channel"
	display_name = "Unclog Privy Channel"
	min_players = 2
	super()


func tick(delta: float) -> void:
	# Advance the bar
	_bar_phase += CYCLE_SPEED * delta * _bar_dir
	if _bar_phase >= 1.0:
		_bar_phase = 1.0
		_bar_dir = -1
	elif _bar_phase <= 0.0:
		_bar_phase = 0.0
		_bar_dir = 1

	# Sync phase to clients for visual (cheap: just broadcast phase each frame)
	_sync_bar.rpc(_bar_phase)

	# Decay slowly if not both participating
	if participating_players.size() < 2:
		progress = max(0.0, progress - 0.02 * delta)


func on_player_press(player_id: int) -> void:
	if not multiplayer.is_server() or is_complete:
		return
	if player_id not in participating_players:
		return

	var t := Time.get_ticks_msec() / 1000.0
	_ready_timestamps[player_id] = t

	# Check if another player pressed recently
	for other_id in _ready_timestamps:
		if other_id == player_id:
			continue
		var diff: float = abs(t - float(_ready_timestamps[other_id]))
		if diff <= SYNC_WINDOW:
			# Both in green zone?
			if GREEN_ZONE_LOW <= _bar_phase and _bar_phase <= GREEN_ZONE_HIGH:
				progress = min(1.0, progress + BURST_PROGRESS)
				_on_sync_success.rpc()
			else:
				progress = min(1.0, progress + SMALL_PROGRESS)
			_ready_timestamps.clear()
			return


@rpc("authority", "call_local", "unreliable")
func _sync_bar(phase: float) -> void:
	_bar_phase = phase
	# Update progress bar mesh scale or shader uniform here (visual only)
	var bar := get_node_or_null("ProgressBar/BarMesh")
	if bar:
		bar.scale.x = phase


@rpc("authority", "call_local", "reliable")
func _on_sync_success() -> void:
	if _prompt:
		_prompt.modulate = Color(0.5, 1.0, 0.5)
		var tween := create_tween()
		tween.tween_property(_prompt, "modulate", Color.WHITE, 0.5)
