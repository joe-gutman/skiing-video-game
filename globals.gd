extends Node

# Player-related variables
var player: Sprite2D
var player_position: Vector2 = Vector2.ZERO
var player_speed: float = 0.0
var player_direction: float = 0.0
var player_normal: Vector2 = Vector2.ZERO
var player_camera: Camera2D

# Ground-related variables
var world_ground: Node2D = null
var ground_normal_sprite: Sprite2D = null 


func _ready():
	player_camera = get_node_or_null("/root/main/Player/Camera2D")
	player = get_node_or_null("/root/main/Player/Sprite2D")
	world_ground = get_node_or_null("/root/main/World/Ground")

func _process(delta: float) -> void:
	# Update player position and normal based on the player's sprite
	if player:
		player_position = player.global_position
		
	# make sure player direction is always within the range of 0 to 360 degrees
	if player_direction < 0:
		player_direction += 360
	elif player_direction >= 360:
		player_direction -= 360
