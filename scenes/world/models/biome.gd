extends RefCounted
class_name WorldBiome

var name: String
var tile_set: TileSet
var density: float
var width: float
var length: float

var ground: AssetGroup                # Always required
var assets: Dictionary = {}           # { String: { "group": AssetGroup, "weight": float } }

# Environmental metadata
var weather: String
var temperature: int
var ambient_sounds: Array
var sky_color: Color
var fog_color: Color

var notes: String

const RNG_POWER = 1

func _init(
		name: String,
		tile_set: TileSet,
		density: float,
		width: float,
		length: float,
		ground: AssetGroup,
		assets: Dictionary = {},       # { name: { "group": AssetGroup, "weight": float } }
		weather: String = "clear",
		temperature: int = 0,
		ambient_sounds: Array = [],
		sky_color: Color = Color.WHITE,
		fog_color: Color = Color.WHITE,
		notes: String = ""
	) -> void:

	self.name = name
	self.tile_set = tile_set
	self.density = density
	self.width = width
	self.length = length
	self.notes = notes

	# Ground is required
	if ground == null:
		push_error("Biome '%s' must define a ground group!" % name)
	else:
		self.ground = ground

	# Assets (optional, e.g. trees, bushes, rocks, decorations)
	self.assets = {}
	for k in assets.keys():
		var entry = assets[k]
		if not entry.has("group") or not (entry["group"] is AssetGroup):
			push_error("Invalid asset group '%s' in biome '%s'" % [k, name])
			continue
		self.assets[k] = {
			"group": entry["group"],
			"weight": float(entry.get("weight", 1.0))
		}

	self.weather = weather
	self.temperature = temperature
	self.ambient_sounds = ambient_sounds
	self.sky_color = sky_color
	self.fog_color = fog_color


func get_ground_asset(rng: RandomNumberGenerator) -> WorldAsset:
	return ground.get_random_asset(rng) if ground != null else null


func get_random_asset(rng: RandomNumberGenerator) -> WorldAsset:
	# 1) Biome-wide sparsity gate
	if rng.randf() > pow(self.density, RNG_POWER):
		print("Biome ", name, ": density gate failed")
		return null
	else: 
		print("Biome ", name, ": density gate passed")

	# 2) Weighted selection of asset groups
	var candidates: Array = []   # [{ "group": AssetGroup, "weight": float }]
	var total_weight := 0.0
	for entry in self.assets.values():
		candidates.append(entry)
		total_weight += float(entry["weight"])

	if total_weight <= 0.0:
		print("Biome ", name, ": no valid asset groups")
		return null

	var choice_point := rng.randf() * total_weight
	print("Biome ", name, ": choice_point=", choice_point, " total_weight=", total_weight)

	var running_total := 0.0
	var selected_group: AssetGroup = null
	for entry in candidates:
		running_total += float(entry["weight"])
		if choice_point < running_total:
			selected_group = entry["group"]
			print("Biome ", name, ": selected group=", selected_group.name)
			break

	# 3) Ask that group for an asset
	return selected_group.get_random_asset(rng) if selected_group != null else null
