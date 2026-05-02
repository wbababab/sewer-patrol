class_name SewerGenerator

# Generates a LevelData dict from a seed using a depth-limited graph walk.
# All coordinates are in grid units (1 unit = 1 room width, scaled at placement).
# Module IDs match scene filenames in scenes/world/modules/.

const ROOM_SIZE := 12.0          # world-space metres per grid cell
const MIN_ROOMS := 8
const MAX_ROOMS := 14
const JOB_POOL: Array[StringName] = [
	&"scrape_curse_moss",
	&"unclog_privy_channel",
	&"burn_leech_nest",
	&"reset_rat_bells",
]
const PROP_POOL: Array[StringName] = [
	"mossy_brick", "barrel_stack", "hanging_lantern",
	"leech_cluster", "root_growth", "old_boot",
	"clay_pot", "shrine_candle",
]

# Module definitions: module_id -> {exits: Array[Vector2i], prop_slots: int, can_host_job: bool}
# Exits are cardinal offsets (N=0,-1  E=1,0  S=0,1  W=-1,0)
const MODULES := {
	"straight_pipe":   {"exits": [Vector2i(0, -1), Vector2i(0, 1)],                             "prop_slots": 1, "can_host_job": false},
	"l_bend":          {"exits": [Vector2i(1, 0),  Vector2i(0, 1)],                             "prop_slots": 1, "can_host_job": false},
	"t_junction":      {"exits": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)],             "prop_slots": 2, "can_host_job": false},
	"small_chamber":   {"exits": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)], "prop_slots": 3, "can_host_job": true},
	"cistern":         {"exits": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)], "prop_slots": 4, "can_host_job": true},
	"aqueduct_span":   {"exits": [Vector2i(-1, 0), Vector2i(1, 0)],                             "prop_slots": 2, "can_host_job": false},
	"dead_end_alcove": {"exits": [],                                                              "prop_slots": 2, "can_host_job": true},
}

# Weighted spawn table per depth bucket: depth 0-2 = early, 3-6 = mid, 7+ = deep
const SPAWN_WEIGHTS_EARLY := {
	"straight_pipe": 4, "l_bend": 3, "small_chamber": 3, "t_junction": 2,
	"aqueduct_span": 1, "cistern": 1, "dead_end_alcove": 1,
}
const SPAWN_WEIGHTS_MID := {
	"straight_pipe": 2, "l_bend": 2, "small_chamber": 4, "t_junction": 3,
	"aqueduct_span": 2, "cistern": 2, "dead_end_alcove": 2,
}
const SPAWN_WEIGHTS_DEEP := {
	"straight_pipe": 1, "l_bend": 1, "small_chamber": 3, "t_junction": 2,
	"aqueduct_span": 1, "cistern": 3, "dead_end_alcove": 2,
}


static func generate(seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# grid_pos -> room dict
	var grid: Dictionary = {}
	var rooms: Array = []
	# Stack of {grid_pos, depth} to visit
	var open_stack: Array = []

	# Place entry room (small_chamber) at origin
	var entry := _make_room("small_chamber", Vector2i(0, 0), 0, rng)
	grid[Vector2i(0, 0)] = entry
	rooms.append(entry)

	for exit_dir in MODULES["small_chamber"].exits:
		open_stack.append({"pos": Vector2i(0, 0) + exit_dir, "depth": 1, "parent_pos": Vector2i(0, 0)})

	var target_rooms := rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	var exit_room_index := -1

	while rooms.size() < target_rooms and open_stack.size() > 0:
		# Pop a random slot from the stack for organic branching
		var idx := rng.randi() % open_stack.size()
		var slot: Dictionary = open_stack[idx]
		open_stack.remove_at(idx)

		var gpos: Vector2i = slot.pos
		if grid.has(gpos):
			continue

		var depth: int = slot.depth
		var module_id := _pick_module(rng, depth, target_rooms, rooms.size())
		var room := _make_room(module_id, gpos, depth, rng)
		grid[gpos] = room
		rooms.append(room)

		# Queue exits, avoiding already-occupied cells
		for exit_dir in MODULES[module_id].exits:
			var next_pos := gpos + exit_dir
			if not grid.has(next_pos) and rooms.size() < target_rooms:
				open_stack.append({"pos": next_pos, "depth": depth + 1, "parent_pos": gpos})

	# Mark the deepest small_chamber or cistern as the exit
	var max_depth := 0
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		if r.depth > max_depth and MODULES[r.module_id].can_host_job:
			max_depth = r.depth
			exit_room_index = i
	if exit_room_index == -1:
		exit_room_index = rooms.size() - 1

	# Distribute jobs across job-capable rooms (1-2 per room)
	var shuffled_jobs := JOB_POOL.duplicate()
	_shuffle(shuffled_jobs, rng)
	var job_index := 0
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		if i == 0 or i == exit_room_index:
			continue  # Keep entry and exit clear
		if MODULES[r.module_id].can_host_job and job_index < shuffled_jobs.size():
			r.job_ids = [shuffled_jobs[job_index]]
			job_index += 1
			if job_index < shuffled_jobs.size() and rng.randf() > 0.6:
				r.job_ids.append(shuffled_jobs[job_index])
				job_index += 1

	# Sprinkle props
	for r in rooms:
		r.prop_ids = _pick_props(rng, r.module_id)

	return {
		"seed_val": seed_val,
		"rooms": rooms,
		"entry_room_index": 0,
		"exit_room_index": exit_room_index,
	}


static func _make_room(module_id: String, gpos: Vector2i, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	# rot_y in increments of 90 degrees — randomised for visual variety
	var rot_steps := rng.randi() % 4
	return {
		"module_id": module_id,
		"grid_x": gpos.x,
		"grid_z": gpos.y,
		"rot_y": rot_steps * 90.0,
		"depth": depth,
		"job_ids": [],
		"prop_ids": [],
	}


static func _pick_module(rng: RandomNumberGenerator, depth: int, target: int, current: int) -> String:
	# Force a terminal room if we're running long
	var remaining := target - current
	if remaining <= 1:
		return "dead_end_alcove"

	var weights: Dictionary
	if depth <= 2:
		weights = SPAWN_WEIGHTS_EARLY
	elif depth <= 6:
		weights = SPAWN_WEIGHTS_MID
	else:
		weights = SPAWN_WEIGHTS_DEEP

	var total := 0
	for w in weights.values():
		total += w
	var roll := rng.randi() % total
	var acc := 0
	for key in weights:
		acc += weights[key]
		if roll < acc:
			return key
	return "straight_pipe"


static func _pick_props(rng: RandomNumberGenerator, module_id: String) -> Array:
	var slots: int = MODULES[module_id].prop_slots
	if slots == 0:
		return []
	var count := rng.randi_range(0, slots)
	var pool := PROP_POOL.duplicate()
	_shuffle(pool, rng)
	var result: Array = []
	for i in count:
		result.append(pool[i % pool.size()])
	return result


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
