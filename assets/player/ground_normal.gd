extends Sprite2D

var shader_material : ShaderMaterial

@onready var player = $main/Player

func _ready():
	# Get the shader material
	shader_material = material as ShaderMaterial

func _process(delta):
	# Make sure we are passing the world position to the shader
	var shader_position = player.global_position

	if shader_material:
		shader_material.set_shader_parameter("world_pos", shader_position)

	print("Ground texture position: ", shader_position)
