class_name TorchFlicker extends OmniLight3D

@export var base_energy: float = 1.4
@export var flicker_speed: float = 10.0
@export var flicker_amount: float = 0.25
# Warm amber — matches Ghibli palette
@export var warm_color: Color = Color(0.91, 0.66, 0.30)

var _noise: FastNoiseLite


func _ready() -> void:
	light_color = warm_color
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.4


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var n := (_noise.get_noise_1d(t * flicker_speed) + 1.0) * 0.5
	light_energy = base_energy + (n - 0.5) * flicker_amount * 2.0
