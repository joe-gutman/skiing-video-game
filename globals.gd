extends Node

# Sun-related
var shadows_enabled: bool = false
var sun: DirectionalLight3D

# Player-related
var player: RigidBody2D
var player_position: Vector2 = Vector2.ZERO
var player_speed: float = 0.0
var player_direction: float = 0.0
var player_normal: Vector2 = Vector2.ZERO
var player_camera: Camera2D

var world_scale: Vector2 = Vector2(2.5, 2.5)
var player_height: int = 0

#  Camera-related
var zoom_step: float = 0.05    # how much to zoom in/out per wheel tick
var min_zoom: float = 0.25    # smallest zoom (closer in)
var max_zoom: float = 1.25    # largest zoom (further out)

const MAX_Z_INDEX = 4096

func get_z_index(element: Node2D, modifier: int = 0) -> int:
	return int(fposmod(element.global_position.y + modifier, MAX_Z_INDEX))

func _ready() -> void:
	player_camera = get_node_or_null("/root/Playfield/Player/Camera2D")
	player = get_node_or_null("/root/Playfield/Player")

func _process(_delta: float) -> void:
	if player:
		player_position = player.global_position

	# keep player_direction within 0–360
	if player_direction < 0:
		player_direction += 360
	elif player_direction >= 360:
		player_direction -= 360

func setup_sun(light: DirectionalLight3D) -> void:
	sun = light
	
# func calculate_shadow_properties(height: float) -> Vector2:
# 	if sun == null:
# 		return Vector2.ZERO
# 	var d: Vector3 = (-sun.global_transform.basis.z).normalized()
# 	var elev_rad: float = asin(clamp(-d.y, -1.0, 1.0)) # Sun elevation angle
# 	var shadow_length = height / tan(elev_rad) # Correct formula
# 	var shadow_direction = deg_to_rad(180 - sun.rotation_degrees.y)
# 	return Vector2(shadow_length, shadow_direction)
