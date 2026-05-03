extends Node3D

const MODULE_SCENES := {
	"straight_pipe":   "res://scenes/world/modules/straight_pipe.tscn",
	"l_bend":          "res://scenes/world/modules/l_bend.tscn",
	"t_junction":      "res://scenes/world/modules/t_junction.tscn",
	"small_chamber":   "res://scenes/world/modules/small_chamber.tscn",
	"cistern":         "res://scenes/world/modules/cistern.tscn",
	"aqueduct_span":   "res://scenes/world/modules/aqueduct_span.tscn",
	"dead_end_alcove": "res://scenes/world/modules/dead_end_alcove.tscn",
}
const PROP_SCENES := {
	"mossy_brick":     "res://scenes/props/mossy_brick.tscn",
	"barrel_stack":    "res://scenes/props/barrel_stack.tscn",
	"hanging_lantern": "res://scenes/props/hanging_lantern.tscn",
	"leech_cluster":   "res://scenes/props/leech_cluster.tscn",
	"root_growth":     "res://scenes/props/root_growth.tscn",
	"old_boot":        "res://scenes/props/old_boot.tscn",
	"clay_pot":        "res://scenes/props/clay_pot.tscn",
	"shrine_candle":   "res://scenes/props/shrine_candle.tscn",
}
const JOB_SCENES := {
	"scrape_curse_moss":    "res://scenes/jobs/ScrapeCurseMoss.tscn",
	"unclog_privy_channel": "res://scenes/jobs/UnclogPrivyChannel.tscn",
	"burn_leech_nest":      "res://scenes/jobs/BurnLeechNest.tscn",
	"reset_rat_bells":      "res://scenes/jobs/ResetRatBells.tscn",
}
const ROLE_DATA := {
	&"muckwarden":    "res://resources/muckwarden_role.tres",
	&"rat_catcher":   "res://resources/rat_catcher_role.tres",
	&"lantern_friar": "res://resources/lantern_friar_role.tres",
}

@onready var _room_root: Node3D = $Rooms
@onready var _job_spawner: Node = $JobSpawner
@onready var _player_spawner: Node = $PlayerSpawner
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _exit_door: Node3D = $ExitDoor

var _level_data: Dictionary = {}


func _ready() -> void:
	if multiplayer.is_server():
		_level_data = GameManager.level_data
		_build_level(_level_data)
		_spawn_players()


func _build_level(data: Dictionary) -> void:
	var rooms: Array = data.rooms
	var all_job_ids: Array[StringName] = []
	var exit_world_pos := Vector3.ZERO

	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var packed: PackedScene = load(MODULE_SCENES[r.module_id])
		var module: Node3D = packed.instantiate()
		module.name = "Room_%d_%s" % [i, r.module_id]
		module.position = Vector3(r.grid_x * SewerGenerator.ROOM_SIZE, 0.0, r.grid_z * SewerGenerator.ROOM_SIZE)
		module.rotation_degrees.y = r.rot_y
		_room_root.add_child(module)

		# Place props
		_place_props(module, r.prop_ids)

		# Place jobs
		for job_id in r.job_ids:
			_place_job(module, job_id, i)
			all_job_ids.append(StringName(job_id))

		if i == data.exit_room_index:
			exit_world_pos = module.position

	# Position exit door at exit room — door mesh is 3 units tall, place center at y=1.5 so it sits on floor
	_exit_door.position = exit_world_pos + Vector3(0, 1.5, -SewerGenerator.ROOM_SIZE * 0.4)

	# Required jobs: all spawned jobs
	GameManager.register_jobs(all_job_ids, all_job_ids.size())

	# Bake navmesh from all room geometry
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		_nav_region.navigation_mesh, source_data, _room_root
	)
	NavigationServer3D.bake_from_source_geometry_data(
		_nav_region.navigation_mesh, source_data
	)


func _place_props(module: Node3D, prop_ids: Array) -> void:
	var slots := module.get_node_or_null("PropSlots")
	if slots == null:
		return
	var markers: Array = slots.get_children()
	for idx in min(prop_ids.size(), markers.size()):
		var prop_id: String = prop_ids[idx]
		if not PROP_SCENES.has(prop_id):
			continue
		var prop: Node3D = (load(PROP_SCENES[prop_id]) as PackedScene).instantiate()
		prop.position = (markers[idx] as Marker3D).position
		module.add_child(prop)


func _place_job(module: Node3D, job_id: String, room_index: int) -> void:
	if not JOB_SCENES.has(job_id):
		return
	var job: Node3D = (load(JOB_SCENES[job_id]) as PackedScene).instantiate()
	job.name = "Job_%s_%d" % [job_id, room_index]
	var anchor := module.get_node_or_null("JobAnchor")
	if anchor:
		job.position = (anchor as Marker3D).position + module.position
	else:
		job.position = module.position
	_job_spawner.add_child(job)
	GameManager.register_job_node(StringName(job_id + "_%d" % room_index), job)


func _spawn_players() -> void:
	var peer_ids := multiplayer.get_peers().duplicate()
	peer_ids.append(multiplayer.get_unique_id())
	var spawn_points: Array = ($PlayerSpawnPoints as Node3D).get_children()
	for i in peer_ids.size():
		var pid: int = peer_ids[i]
		var role_id: StringName = GameManager.player_roles.get(pid, &"muckwarden")
		var player_scene: PackedScene = _load_role_scene(role_id)
		var player := player_scene.instantiate() as PlayerBase
		player.name = "Player_%d" % pid
		player.set_multiplayer_authority(pid)
		if ROLE_DATA.has(role_id):
			player.role_data = load(ROLE_DATA[role_id])
		if i < spawn_points.size():
			player.position = (spawn_points[i] as Marker3D).position
		_player_spawner.add_child(player)
		GameManager.players[pid] = player


func _load_role_scene(role_id: StringName) -> PackedScene:
	match role_id:
		&"rat_catcher":   return load("res://scenes/player/RatCatcher.tscn")
		&"lantern_friar": return load("res://scenes/player/LanternFriar.tscn")
		_:                return load("res://scenes/player/Muckwarden.tscn")
