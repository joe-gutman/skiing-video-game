extends RigidBody2D

const IDLE = "IDLE"
const STOP = "STOP"
const MOVE = "MOVE"
const GRIND = "GRIND"
const LAND = "LAND"
const AIRBORNE = "AIRBORNE"
const CRASH = "CRASH"

var player_status: String = IDLE

@export_group("Movement Settings")
@export var idle_speed: float = 5.0;
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

@export_group("Sprites")
@export var player_tilemap: Texture

# Sprite variables
@onready var viewport = $SpriteViewport
@onready var player_sprite = $Sprite2D
@onready var sprite_size = Vector2(player_tilemap.get_width(), player_tilemap.get_height())
@onready var character3D = $SpriteViewport/Node3D/GroundPivot/AirbornePivot/Character3D
@onready var ground_pivot = $SpriteViewport/Node3D/GroundPivot
@onready var airborne_pivot = $SpriteViewport/Node3D/GroundPivot/AirbornePivot

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
	player_sprite.texture = viewport.get_texture()

func _draw():
	if linear_velocity.length() > 0.1:
		var line_length = linear_velocity.length() * 0.1
		var local_velocity = transform.basis_xform_inv(linear_velocity)
		draw_line(Vector2.ZERO, local_velocity.normalized() * line_length, Color.RED, 2.0)

func _physics_process(delta: float) -> void:
	print("Player Status: ", player_status)
	var input_vector = Vector2.ZERO
	player_sprite.rotation = -rotation
	ground_pivot.rotation.y = -rotation

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
			
			ground_pivot.rotation.z = lerp_angle(ground_pivot.rotation.z, target_rotation_z, 0.05)
			
			if abs(rad_to_deg(ground_pivot.rotation.z) - rad_to_deg(target_rotation_z)) < 1.0:
				ground_pivot.rotation.z = 0.0
				player_status = IDLE
				crash_timer = 0.0
		else:
			apply_force(-linear_velocity.normalized() * crash_slowdown_rate)

			if target_rotation_z == 0.0:
				if player_direction.x > 0:
					target_rotation_z = deg_to_rad(-90)
				else:
					target_rotation_z = deg_to_rad(90)
			
			ground_pivot.rotation.z = lerp_angle(ground_pivot.rotation.z, target_rotation_z, 0.08)
			
			if linear_velocity.length() < 1.0:
				linear_velocity = Vector2.ZERO

	if player_status == AIRBORNE:
		print(AIRBORNE)
		# if input_vector.y != 0:
		# 	airborne_pivot.rotation.x -= deg_to_rad(rotation_speed * input_vector.y * delta)
		
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - jump_start_time
		
		if elapsed_time < jump_duration:
			var jump_progress = elapsed_time / jump_duration
			var eased_progress
			
			if jump_progress < 0.5:
				eased_progress = ease_out_quad(jump_progress * 2)
			else:
				eased_progress = 1 - ease_in_quad((jump_progress - 0.5) * 2)
			
			var vertical_movement = lerp(0.0, standing_jump_max_height, eased_progress)
			
			ground_pivot.position.y = vertical_movement

		else:
			ground_pivot.position.y = 0.0
			player_status = LAND
			
	if player_status == LAND:
		print(velocity_direction_difference)
		
		var is_direction_safe = (
			velocity_direction_difference < crash_angle or 
			abs(velocity_direction_difference - 180) < crash_angle
		)
		var is_speed_safe = linear_velocity.length() < crash_speed
		# var is_x_rotation_aligned = abs(character3D.rotation.x) < deg_to_rad(5)  # Example threshold

		if (is_direction_safe or is_speed_safe):
			player_status = IDLE
		else:
			player_status = CRASH
			print(player_status)


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

	queue_redraw()
