extends RefCounted
class_name WorldAsset

var name: String
var type: String = "sprite"   # "sprite" | "scene"

# For sprite assets
var atlas_coords: Vector2i
var src_id: int
var alt_id: int = 0
var categories: Array = []

# For scene assets
var scene: PackedScene = null


func _init(name: String, def: Dictionary) -> void:
	self.name = name
	self.type = def.get("type", "sprite")

	if type == "sprite":
		var coords: Array = def.get("atlas_coords", [0, 0])
		atlas_coords = Vector2i(coords[0], coords[1])
		src_id = int(def.get("src_id", 0))
		alt_id = int(def.get("alt_id", 0))
		categories = def.get("categories", []).duplicate()
	elif type == "scene":
		if def.has("scene"):
			scene = load(def["scene"]) as PackedScene
		else:
			push_error("WorldAsset '%s' of type 'scene' missing 'scene' path" % name)
