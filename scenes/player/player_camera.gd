extends Camera2D

var current_zoom: float = Globals.min_zoom  # intuitive zoom: min = close up

func to_godot_zoom(intuitive_zoom: float) -> float:
	return 1.0 / intuitive_zoom

func _ready() -> void:
	# Apply starting zoom immediately
	zoom = Vector2(to_godot_zoom(current_zoom), to_godot_zoom(current_zoom))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# zoom in (decrease intuitive zoom value)
			current_zoom = clamp(current_zoom - Globals.zoom_step, Globals.min_zoom, Globals.max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# zoom out (increase intuitive zoom value)
			current_zoom = clamp(current_zoom + Globals.zoom_step, Globals.min_zoom, Globals.max_zoom)

		var godot_zoom = to_godot_zoom(current_zoom)
		zoom = Vector2(godot_zoom, godot_zoom)
