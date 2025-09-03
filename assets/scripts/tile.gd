extends Resource
class_name Tile

@export var name: String
@export var coords: Vector2i
@export var weight: float
@export var alt_id: int = 0

func _to_string() -> String:
    return "%s (%s)" % [name, coords]