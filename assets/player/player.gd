extends RigidBody2D

@export_group("Movement Settings")
@export var max_accel_rate: float = 10000.0
@export var max_speed: float = 600.0
@export var max_friction: float = 5.0
@export var min_friction: float = 0.25
@export var rotation_speed: float = 200.0
@export var velocity_alignment_str: float = 5.0
@export var stopping_strength: float = 250.0

var gravity : int = ProjectSettings.get_setting("physics/2d/default_gravity")
var downhill_vector: Vector2 = Vector2(0, 1)
var player_force: float = 0.0

@export_group("Sprites")
@export var player_tilemap: Texture

@onready var player_sprite = $Sprite2D
@onready var sprite_size = Vector2(player_tilemap.get_width(), player_tilemap.get_height())

func _ready() -> void:
	add_constant_force(gravity * downhill_vector)
	player_sprite.texture = player_tilemap
	player_sprite.region_rect = Rect2(Vector2(sprite_size.y * 4, 0), Vector2(sprite_size.y, sprite_size.y))

func _draw():
	if linear_velocity.length() > 0.1:
		var line_length = linear_velocity.length() * 0.1
		var local_velocity = transform.basis_xform_inv(linear_velocity)
		draw_line(Vector2.ZERO, local_velocity.normalized() * line_length, Color.RED, 2.0)


func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Keyboard input
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		input_vector.y = 1  # Forward
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		input_vector.y = -1   # Backward
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		input_vector.x = -1  # Left
	elif Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		input_vector.x = 1   # Right

	# Calculate player facing and movement direction
	# downhill_factor is between [-1, 1]; -1 is uphill, 1 is downhill
	var player_direction = Vector2(-sin(rotation), cos(rotation))
	var velocity_direction = linear_velocity.normalized()
	var velocity_downhill_factor = ((velocity_direction.dot(downhill_vector) + 1) / 2)

	# Calculate player speed based on input
	if input_vector.y != 0:
		# Calculate player speed
		player_force = max_accel_rate * velocity_downhill_factor  * input_vector.y
		print("Player Force:", int(round(player_force)))
		# Lerp movement direction towards player facing direction
		var lerped_direction = (velocity_direction * input_vector.y).lerp((player_direction), velocity_alignment_str)
		
		# Apply central force in the lerped direction
		var final_force = player_force * lerped_direction * delta
		apply_central_force(final_force)
		print("Player Speed:", int(round(linear_velocity.length())))



	# Apply rotation
	if input_vector.x != 0:
		var torque = input_vector.x * rotation_speed
		apply_torque(torque)

	# Handle when there's no input
	if input_vector.y == 0:
		# Calculate angle difference between velocity and player direction for stopping force
		var angle_diff = abs(player_direction.angle_to(velocity_direction))
		var max_angle_diff = deg_to_rad(90)
		var angle_threshold = deg_to_rad(30)
		var stopping_factor = 0.0
		if angle_diff > angle_threshold:
			stopping_factor = clamp((angle_diff - angle_threshold) / (max_angle_diff - angle_threshold), 0, 1)

		# Apply the stopping force
		var stopping_force = -velocity_direction * stopping_factor * stopping_strength
		apply_central_force(stopping_force)

		# Apply gravity counteracting force
		var opposite_gravity_force = -gravity * downhill_vector
		apply_central_force(opposite_gravity_force)

		# Apply smooth friction when there's no input (decay to zero velocity)
		if linear_velocity.length() < 0.5:
			linear_velocity = Vector2.ZERO
		else:
			var friction = linear_velocity.normalized() * -min_friction  # Small friction force
			apply_central_force(friction)


		

	Globals.player_speed = linear_velocity.length()
	queue_redraw()
