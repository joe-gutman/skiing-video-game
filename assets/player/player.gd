extends RigidBody2D

var DEBUG = false

const IDLE = "IDLE"
const STOP = "STOP"
const MOVE = "MOVE"
const GRIND = "GRIND"
const LAND = "LAND"
const AIRBORNE = "AIRBORNE"
const CRASH = "CRASH"

var player_status: String = IDLE

@export_group("Movement Settings")
@export var idle_speed: float = 5.0
@export var max_accel_rate: float = 10000.0
@export var max_speed: float = 600.0
@export var max_friction: float = 5.0
@export var min_friction: float = 0.25
@export var rotation_speed: float = 200.0
@export var velocity_alignment_str: float = 5.0
@export var stopping_strength: float = 250.0
@export var crash_length: float = 3.0 # seconds
@export var crash_angle: float = 65.0 # degrees
@export var crash_speed: float = 25.0 
@export var crash_slowdown_rate: float = 250.0
@export var standing_jump_max_height: float = .25

var gravity : int = ProjectSettings.get_setting("physics/2d/default_gravity")
var downhill_vector: Vector2 = Vector2(0, 1)
var opposite_gravity_force = -gravity * downhill_vector
var player_force = 0.0
var crash_timer = 0.0
var target_rotation_z = 0.0
var normal = Vector2.ZERO
var original_z_index: int
const TILEMAP_COLLISION_LAYER = 2

# Sprite variables
@onready var sprite = $Sprite2D
@onready var init_sprite_size = sprite.texture.get_size()
@onready var character3D = $SpriteViewport/Node3D/GroundPivot/AirbornePivot/Character3D
@onready var foot_pivot = $SpriteViewport/Node3D/GroundPivot
@onready var chest_pivot = $SpriteViewport/Node3D/GroundPivot/AirbornePivot
@onready var ground_normal_viewport = $SubViewport
@onready var ground_normal_sprite = $SubViewport/GroundNormal
@onready var ground_normal_texture = $SubViewport/GroundNormal.texture

# Jump variables
var jump_start_time = 0.0
var jump_duration = 0.0
var manual_jump_force = 50.0

func ease_out_quad(t):
	return t * (2 - t)

func ease_in_quad(t):
	return t * t

func _ready() -> void:
	add_constant_force(gravity * downhill_vector)
	original_z_index = z_index

func get_normal_at_position(world_position: Vector2) -> Vector3:
	# Ensure latest texture update from subviewport
	var img = ground_normal_viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)  # Ensure the image format is RGBA

	# Get texture size
	var img_size = img.get_size()

	# Convert world position to local space of the sprite
	var sprite_transform = ground_normal_sprite.global_transform.affine_inverse()
	var local_pos = sprite_transform * world_position

	# Convert local position to UV coordinates (0-1 range)
	var uv = Vector2(
		local_pos.x / ground_normal_viewport.size.x,
		1.0 - (local_pos.y / ground_normal_viewport.size.y)  # Flip Y-axis
	)

	# Clamp UV to make sure it's within the texture boundaries
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)

	# Convert to pixel coordinates (Ensure it's a floating-point Vector2)
	var pixel_pos = uv * Vector2(img_size.x, img_size.y)

	# Now, we will sample the normal map around this position (5x5 grid)
	var total_normal = Vector2.ZERO
	var sample_count = 0

	# Sample the 5x5 area around the pixel (3x3 area centered on player position)
	for x in range(-2, 3):  # -2 to 2 gives a 5x5 grid
		for y in range(-2, 3):
			var sample_pos = pixel_pos + Vector2(x, y)
			if sample_pos.x >= 0 and sample_pos.x < img_size.x and sample_pos.y >= 0 and sample_pos.y < img_size.y:
				var color = img.get_pixelv(sample_pos.floor())
				var normal = Vector2(
					(color.r - 0.5) * 2.0,  # Red channel (X normal)
					(color.g - 0.5) * 2.0   # Green channel (Y normal)
				)
				total_normal += normal
				sample_count += 1

	if sample_count == 0:
		return Vector3(0, 1, 0)  # Default to upright if no samples

	# Calculate the average normal from the samples
	var average_normal = total_normal / sample_count

	# Normalize the average normal to ensure it's a unit vector
	var normalized_normal = average_normal.normalized()

	# Convert the 2D normal to a 3D normal (assuming flat terrain in X-Z plane)
	return Vector3(normalized_normal.x, 0, normalized_normal.y).normalized()




func _draw():
	if linear_velocity.length() > 0.1:
		var line_length = linear_velocity.length() * 0.1
		var local_velocity = transform.basis_xform_inv(linear_velocity)
		draw_line(Vector2.ZERO, local_velocity.normalized() * line_length, Color.RED, 2.0)

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO
	sprite.rotation = -rotation
	foot_pivot.rotation.y = -rotation


	# --------------- Normal Map Sampling ---------------
	# Uncomment this section to sample the normal map at the player's position to simulate sking on non flat terrain.


	# # Sample the normal map at the given position (2D normal map)
	#var normal = get_normal_at_position(position)
	# print("Normal Map Sampled Normal: ", normal, " at Position: ", position)

	# # Convert the 2D normal map's normal to a 3D normal
	# In the normal map, normal.x represents the X direction, and normal.y represents the Z direction
	# var normal_3d = Vector3(
	 	# (normal.x - 0.5) * 2.0,  # Red channel for X (normalized to range [-1, 1]) 
	# 	0,  # Y is 0 for this 2D context, we're ignoring the vertical component
	# 	(normal.y - 0.5) * 2.0   # Green channel for Z (normalized to range [-1, 1])
	# )

	# # Normalize the normal to ensure it is a unit vector
	# normal_3d = normal_3d.normalized()

	# # Calculate the angle in 2D from the normal (ignore the Y-axis, focus on X and Z for 2D)
	# var angle = -atan2(normal_3d.z, normal_3d.x)  # Rotation angle on the 2D plane (around the Z-axis)

	# # Apply the rotation to the 3D player object (foot_pivot)
	# # Since rotation is a Vector3, we only modify the Z component for 2D rotation.
	# foot_pivot.rotation.x = angle - 90

	# -----------------------------------------------------


	if Input.is_action_pressed("move_up"):
		input_vector.y = 1  # Forward
	elif Input.is_action_pressed("move_down"):
		input_vector.y = -1  # Backward

	if Input.is_action_pressed("move_left"):
		input_vector.x = -1  # Left
	elif Input.is_action_pressed("move_right"):
		input_vector.x = 1  # Right

	var player_direction = Vector2(-sin(rotation), cos(rotation))
	var player_downhill_factor = ((player_direction.dot(downhill_vector) + 1) / 2)

	var velocity_direction = linear_velocity.normalized()
	var velocity_downhill_factor = ((velocity_direction.dot(downhill_vector) + 1) / 2)

	var velocity_direction_difference = rad_to_deg(abs(player_direction.angle_to(velocity_direction)))

	if player_status == CRASH:
		crash_timer += delta
		if crash_timer > crash_length:
			linear_velocity = Vector2.ZERO
			
			target_rotation_z = 0.0
			
			foot_pivot.rotation.z = lerp_angle(foot_pivot.rotation.z, target_rotation_z, 0.05)
			
			if abs(rad_to_deg(foot_pivot.rotation.z) - rad_to_deg(target_rotation_z)) < 1.0:
				foot_pivot.rotation.z = 0.0
				player_status = IDLE
				crash_timer = 0.0
		else:
			apply_force(-linear_velocity.normalized() * crash_slowdown_rate)

			if target_rotation_z == 0.0:
				if player_direction.x > 0:
					target_rotation_z = deg_to_rad(-90)
				else:
					target_rotation_z = deg_to_rad(90)
			
			foot_pivot.rotation.z = lerp_angle(foot_pivot.rotation.z, target_rotation_z, 0.08)
			
			if linear_velocity.length() < 1.0:
				linear_velocity = Vector2.ZERO

	if player_status == AIRBORNE:
		set_collision_mask_value(TILEMAP_COLLISION_LAYER, false)
		z_index = original_z_index + 1

		# if input_vector.y != 0:
		# 	chest_pivot.rotation.x -= deg_to_rad(rotation_speed * input_vector.y * delta)
		
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - jump_start_time
		
		if elapsed_time < jump_duration:
			var jump_progress = elapsed_time / jump_duration
			var eased_progress
			
			if jump_progress < 0.5:
				eased_progress = ease_out_quad(jump_progress * 2)
			else:
				eased_progress = 1 - ease_in_quad((jump_progress - 0.5) * 2)
			
			var vertical_movement = lerp(0.0, standing_jump_max_height, eased_progress)
			
			foot_pivot.position.y = vertical_movement

		else:
			foot_pivot.position.y = 0.0
			player_status = LAND
			
	if player_status == LAND:		
		set_collision_mask_value(TILEMAP_COLLISION_LAYER, true)
		z_index = original_z_index
		
		var is_direction_safe = (
			velocity_direction_difference < crash_angle or 
			abs(velocity_direction_difference - 180) < crash_angle
		)
		var is_speed_safe = linear_velocity.length() < crash_speed

		if (is_direction_safe or is_speed_safe):
			player_status = IDLE
		else:
			player_status = CRASH

	if Input.is_action_just_pressed("jump") and player_status != AIRBORNE:
		player_status = AIRBORNE
		jump_start_time = Time.get_ticks_msec() / 1000.0  # Get time in seconds	
		jump_duration = (2 * manual_jump_force) / gravity 

	if player_status != AIRBORNE and player_status != CRASH:
		# friction, skid stop, slow down based on how much the player is turning
		if abs(player_direction.angle_to(velocity_direction)) > deg_to_rad(10): 
			if velocity_direction_difference > 90:
				velocity_direction_difference = 180 - velocity_direction_difference

			var max_stopping_force = stopping_strength  
			var angle_threshold = 90

			var stopping_ratio = clamp((velocity_direction_difference / angle_threshold), 0, 1)

			var stopping_force = -velocity_direction * stopping_ratio * max_stopping_force
			apply_central_force(stopping_force)

			if velocity_direction_difference >= angle_threshold:
				player_status = STOP

		if input_vector.y != 0.0:
			player_status = MOVE
			player_force = max_accel_rate * velocity_downhill_factor * input_vector.y
			var lerped_direction = (velocity_direction * input_vector.y).lerp(player_direction, velocity_alignment_str)
			var final_force = player_force * lerped_direction * delta
			apply_central_force(final_force)


		elif (player_status == STOP or input_vector.y == 0.0) and player_status != AIRBORNE:
			apply_central_force(opposite_gravity_force)

			var friction = linear_velocity.normalized() * -min_friction  # Small friction force
			apply_central_force(friction)

			if linear_velocity.length() < 5.0:
				player_status = IDLE
				linear_velocity = Vector2.ZERO


		elif player_status == IDLE:
			apply_central_force(opposite_gravity_force)
			linear_velocity = Vector2.ZERO

	if input_vector.x != 0 and player_status != CRASH: 
		var torque = 0
		if player_status == AIRBORNE:
			torque = input_vector.x * rotation_speed * 2.0
		else:
			torque = input_vector.x * rotation_speed

		apply_torque(torque)

	# convert x and y vector to degrees
	Globals.player_direction = player_direction.angle()
	Globals.player_position = position
	Globals.player_speed = linear_velocity.length()
	queue_redraw()
