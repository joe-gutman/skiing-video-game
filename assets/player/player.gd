extends RigidBody2D

@export_group("Movement Settings")
@export var accel_rate_downhill: float = 10.0
@export var accel_rate_uphill: float = 1.0
@export var max_speed_downhill: float = 250.0
@export var max_speed_uphill: float = 50.0
@export var max_friction: float = 5.0
@export var min_friction: float = 0.25
@export var rotation_speed: float = 5.0
@export var velocity_alignment_str: float = 0.5

var gravity : int = ProjectSettings.get_setting("physics/2d/default_gravity")
var downhill_vector: Vector2 = Vector2(0, 1)
var player_speed: float = 0.0

@export_group("Sprites")
@export var player_tilemap: Texture

@onready var player_sprite = $Sprite2D
@onready var sprite_size = Vector2(player_tilemap.get_width(), player_tilemap.get_height())

func _ready() -> void:
	player_sprite.texture = player_tilemap
	player_sprite.region_rect = Rect2(Vector2(sprite_size.y * 4, 0), Vector2(sprite_size.y, sprite_size.y))

func _draw():
	if linear_velocity.length() > 0.1:
		var line_length = linear_velocity.length() * 0.1
		var local_velocity = transform.basis_xform_inv(linear_velocity)
		draw_line(Vector2.ZERO, local_velocity.normalized() * line_length, Color.RED, 2.0)


func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO
	# set_constant_force(Vector2(0, gravity)) # counteract gravity

	# Keyboard input
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		input_vector.y = 1  # Forward
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		input_vector.y = -1   # Backward
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		input_vector.x = -1  # Left
	elif Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		input_vector.x = 1   # Right

	# Calculate player direction
	var player_direction = Vector2(-sin(rotation), cos(rotation))
	var downhill_factor = player_direction.dot(downhill_vector)

	# Calculate player speed based on input
	if input_vector.y != 0:
		# Calculate acceleration and max speed based on slope factor
		var accel_rate = accel_rate_downhill if downhill_factor > 0 else accel_rate_uphill
		var max_speed = max_speed_downhill if downhill_factor > 0 else max_speed_uphill

		# Calculate player speed
		player_speed += accel_rate * downhill_factor * input_vector.y
		player_speed = clamp(player_speed, -max_speed, max_speed)
	else:
		# When no input, apply friction to stop player
		if abs(player_speed) > 0.1:
			var friction_factor = (1 - downhill_factor) / 2
			var friction = (max_friction * friction_factor) + min_friction
			player_speed += sign(player_speed) * (-friction * abs(downhill_factor))
		else:
			player_speed = 0

	# Calculate stopping force based on angle difference between player direction and velocity direction, simulation ski friction
	var velocity_direction = linear_velocity.normalized()
	var angle_diff = abs(player_direction.angle_to(velocity_direction))
	var max_angle_diff = deg_to_rad(180)
	var angle_threshold = deg_to_rad(60)
	var stopping_factor = 0.0
	if angle_diff > angle_threshold:
		stopping_factor = clamp((angle_diff - angle_threshold) / (max_angle_diff - angle_threshold), 0, 1)

	# Apply stopping impulse
	var stopping_strength = 5
	var stopping_impulse = -velocity_direction * stopping_factor * stopping_strength
	apply_central_impulse(stopping_impulse)

	# Adjust speed based on slope factor
	var adjusted_player_speed = player_speed * (1 + downhill_factor * 0.5)

	# Calculate velocity and torque
	var velocity = player_direction * adjusted_player_speed
	var torque = input_vector.x * rotation_speed

	# Align velocity with player direction
	var speed_factor = linear_velocity.length() / max_speed_downhill
	var adjusted_velocity_alignment_str = velocity_alignment_str / (1 + speed_factor) + 5
	linear_velocity = linear_velocity.lerp(velocity, velocity_alignment_str * delta)

	# Apply movement 
	if input_vector.y != 0:
		apply_central_impulse(velocity * delta)

	# Apply rotation
	if input_vector.x != 0:
		apply_torque_impulse(torque)

	print(downhill_factor, player_speed, velocity)

	Globals.player_speed = linear_velocity.length()
	queue_redraw()
