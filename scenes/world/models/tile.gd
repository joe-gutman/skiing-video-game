extends RefCounted
class_name LayerTile

var name: String
var atlas_coords: Vector2i
var src_id: int
var alt_id: int
var categories: Array

func _init( name: String, atlas_coords: Vector2i, src_id: int, alt_id: int = 0, categories: Array = []) -> void:
    self.name = name
    self.atlas_coords = atlas_coords
    self.src_id = src_id
    self.alt_id = alt_id
    self.categories = categories.duplicate()

