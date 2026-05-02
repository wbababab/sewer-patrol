class_name JobDefinition extends Resource

@export var job_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
# Roles with these tags can start the job (empty = any role)
@export var required_role_tags: Array[StringName] = []
@export var min_players: int = 1
@export var max_players: int = 4
@export var base_duration: float = 8.0
@export var pay_reward: int = 50
@export var job_scene: PackedScene
