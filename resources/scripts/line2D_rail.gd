extends Line2D

@onready var path = get_parent().get_node("Path2D")

func _ready():
	update_line()

func update_line():
	clear_points()
	
	if path and path.curve:
		var curve = path.curve
		for i in range(curve.get_point_count()):
			var point = curve.get_point_position(i)
			add_point(point)
