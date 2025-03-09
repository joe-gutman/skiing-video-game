extends Line2D

@export_group("Trail Settings")
@export var max_trail_length: int = 10 # 0 for infinite
@export var trail_point_interval: float = 0.25 # Time in seconds between adding points
@export var trail_offset_distance: float = 8
var trail_points: Array = []
var time_since_last_point: float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics(delta: float) -> void:
	# # Get the player's position with an offset based on rotation
		# var offset = Vector2(-trail_offset_distance, 0).rotated(speed_vector.angle())
		# offset = Vector2(round(offset.x), round(offset.y))  # Round offset to nearest integer
		# var trail_point = global_position + offset
		# trail_point = Vector2(round(trail_point.x), round(trail_point.y))  # Round trail point to nearest integer


		# # Initialize the trail if it doesn't exist
		# if trail_points.size() == 0:
		# 	trail_points.append(trail_point)
		# 	player_trail.add_point(trail_point)
		# else: # Update the last point if it exists
		# 	if trail_points[-1] != trail_point:  # Check if the new point is different
		# 		trail_points[-1] = trail_point
		# 		player_trail.set_point_position(trail_points.size()-1, trail_point)

		# if speed > 15:
		# 	time_since_last_point += delta  # Accumulate elapsed time
		# 	if time_since_last_point >= trail_point_interval:
		# 		time_since_last_point = 0.0
		# 		# Calculate a new point based on the player's movement
		# 		var new_trail_point = global_position + speed_vector.normalized() * trail_offset_distance
		# 		new_trail_point = Vector2(round(new_trail_point.x), round(new_trail_point.y))  # Round to nearest integer
				
		# 		if new_trail_point != trail_points[-1]:  # Check if the new point is different
		# 			trail_points.append(new_trail_point)
		# 			player_trail.add_point(new_trail_point)

		# 		if trail_points.size() > max_trail_length and not max_trail_length == 0:
		# 			trail_points.remove_at(0)  # Remove the first point
		# 			player_trail.remove_point(0)  # Remove the first point from the trail

		# 		print(trail_points)
	pass
