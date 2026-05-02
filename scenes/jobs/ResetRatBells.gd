class_name ResetRatBells extends JobBase
# Rat-Catcher visits 3 bell-posts in order.
# Bell posts are child Marker3D nodes: BellPost0, BellPost1, BellPost2.
# Progress = sequence_index / 3.

const BELL_RADIUS := 1.8
const BELL_COUNT := 3

var _sequence_index: int = 0
var _bell_positions: Array[Vector3] = []


func _ready() -> void:
	job_id = &"reset_rat_bells"
	display_name = "Reset Rat Bells"
	required_roles = [&"rat_catcher"]
	super()
	_cache_bell_positions()


func _cache_bell_positions() -> void:
	for i in BELL_COUNT:
		var marker := get_node_or_null("BellPost%d" % i)
		if marker:
			_bell_positions.append(marker.global_position)
		else:
			_bell_positions.append(global_position + Vector3(i * 2.0 - 2.0, 0, 0))


func tick(_delta: float) -> void:
	# Check if the participating Rat-Catcher is near the next bell
	if _sequence_index >= BELL_COUNT:
		return
	var target_pos: Vector3 = _bell_positions[_sequence_index]
	for pid in participating_players:
		var player := GameManager.players.get(pid) as PlayerBase
		if player == null:
			continue
		if player.global_position.distance_to(target_pos) < BELL_RADIUS:
			_ring_bell(_sequence_index)
			return


func _ring_bell(index: int) -> void:
	_sequence_index += 1
	progress = float(_sequence_index) / float(BELL_COUNT)
	_on_bell_rung.rpc(index)


@rpc("authority", "call_local", "reliable")
func _on_bell_rung(index: int) -> void:
	if _prompt:
		_prompt.text = "Bell %d/%d !" % [index + 1, BELL_COUNT]
		var tween := create_tween()
		tween.tween_interval(0.8)
		tween.tween_callback(_update_prompt)
	# Highlight next bell visually
	var next := get_node_or_null("BellPost%d" % (index + 1))
	if next and next.has_method("pulse"):
		next.pulse()
