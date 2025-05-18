extends Sprite2D

var shader_material : ShaderMaterial

func _ready():
	# Get the shader material
	shader_material = material as ShaderMaterial

func _process(delta):
	# Make sure we are passing the world position to the shader
	if shader_material:
		shader_material.set_shader_parameter("world_pos", Globals.player_position)

	position = Globals.player_position
