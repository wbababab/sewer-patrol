class_name SewModuleBase extends Node3D
# Base class for all sewer room modules.
# Each module scene should have:
#   - MeshInstance3D (geometry)
#   - CollisionShape3D (or StaticBody3D with collision)
#   - PropSlots/   (Marker3D children for prop placement)
#   - JobAnchor    (Marker3D, centre of the room floor)
#   - Connection_N/E/S/W  (Marker3D, doorway positions)

@export var module_id: String = ""
@export var prop_slots: int = 2
@export var can_host_job: bool = false
