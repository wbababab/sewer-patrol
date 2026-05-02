extends StaticBody3D

@onready var _shape: CollisionShape3D = $ExitCollision
@onready var _mesh: MeshInstance3D = $ExitMesh
@onready var _label: Label3D = $Label3D
@onready var _trigger: Area3D = $ExitTrigger

var _unlocked: bool = false


func _ready() -> void:
	add_to_group("exit_door")
	_trigger.body_entered.connect(_on_body_entered)


func unlock() -> void:
	_unlocked = true
	_shape.disabled = true
	var tween := create_tween()
	tween.tween_property(_mesh, "modulate", Color(0.5, 1.0, 0.5, 0.3), 0.6)
	if _label:
		_label.text = "EXIT OPEN"
		_label.modulate = Color(0.5, 1.0, 0.5)


func _on_body_entered(body: Node3D) -> void:
	if _unlocked and body.is_in_group("players") and multiplayer.is_server():
		GameManager.finish_run()
