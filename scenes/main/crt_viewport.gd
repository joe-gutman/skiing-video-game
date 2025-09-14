extends Control

@export_range(0.1, 1.0, 0.01)
var resolution_scale: float = 1.0  # 1.0 = full resolution; lower values reduce SubViewport size

func _ready():
	_update_sizes()
	set_process_input(true)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_sizes()

func _update_sizes():
	var screen_size = get_viewport().size
	size = screen_size  # Fill viewport

	var subviewport = get_node("ColorRect/SubViewport")
	if subviewport:
		# Scale SubViewport resolution relative to screen size
		subviewport.size = screen_size * resolution_scale
	else:
		push_error("SubViewport node not found! Check node path.")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Globals.zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Globals.zoom_out()
