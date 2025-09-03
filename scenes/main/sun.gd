# sun.gd
extends DirectionalLight3D

func _ready() -> void:
	Globals.setup_sun(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		emit_signal("shadows_updated")
