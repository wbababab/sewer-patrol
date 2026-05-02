class_name PlayerRoleData extends Resource

@export var role_id: StringName = &""
@export var display_name: String = ""
@export var flavor_text: String = ""
@export var max_health: int = 100
@export var move_speed: float = 4.0
@export var interaction_range: float = 2.0
@export var special_cooldown: float = 8.0
# Job tags this role can interact with (empty = all tags allowed)
@export var allowed_job_tags: Array[StringName] = []
@export var role_color: Color = Color.WHITE
