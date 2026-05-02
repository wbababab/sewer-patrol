extends Node

# Bus indices — set up matching buses in Godot's Audio panel
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_AMBIENT := "Ambient"

var _music_player := AudioStreamPlayer.new()
var _ambient_player := AudioStreamPlayer.new()


func _ready() -> void:
	_music_player.bus = BUS_MUSIC
	_ambient_player.bus = BUS_AMBIENT
	add_child(_music_player)
	add_child(_ambient_player)


func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, fade_in)


func play_ambient(stream: AudioStream, fade_in: float = 2.0) -> void:
	_ambient_player.stream = stream
	_ambient_player.volume_db = -80.0
	_ambient_player.play()
	var tween := create_tween()
	tween.tween_property(_ambient_player, "volume_db", -6.0, fade_in)


func stop_music(fade_out: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(_music_player.stop)


func set_bus_volume(bus: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)
