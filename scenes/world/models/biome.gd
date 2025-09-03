extends RefCounted
class_name WorldBiome

var name: String
var biome_tileset: TileSet
var biome_density: float
var layers: Dictionary    # { LayerType: { "layer": BiomeLayer, "weight": float }, ... }

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
		biome_tileset: TileSet,
		biome_density: float,
		layers: Dictionary,
		weather: String = "clear",
		temperature: int = 0,
		ambient_sounds: Array = [],
		sky_color: Color = Color.WHITE,
		fog_color: Color = Color.WHITE,
		notes: String = ""
	) -> void:

	self.name = name
	self.biome_tileset = biome_tileset
	self.biome_density = biome_density
	self.notes = notes
	self.layers = {}

	if layers.is_empty():
		push_error("Biome '%s' must define at least one layer!" % name)
		return
	add_layers(layers)

	self.weather = weather
	self.temperature = temperature
	self.ambient_sounds = ambient_sounds
	self.sky_color = sky_color
	self.fog_color = fog_color

func add_layer(layer: BiomeLayer, layer_weight: float = 0.5) -> void:
	if not (layer is BiomeLayer):
		push_error("Layer must be a Layer type but got %s." % typeof(layer))
		return
	if self.layers.has(layer.get_layer_type()):
		push_error("Layer with layer_type '%s' already exists." % layer.get_layer_type())
		return
	self.layers[layer.get_layer_type()] = {
		"layer": layer,
		"weight": layer_weight
	}

func add_layers(layers: Dictionary) -> void:
	for layer in layers.values():
		add_layer(layer["layer"], layer["weight"])
 
func get_layers() -> Array:
	return self.layers.values()

func get_layer(layer_type: int) -> BiomeLayer:
	if self.layers.has(layer_type):
		return self.layers[layer_type]["layer"]
	return null

func get_ground_tile(rng: RandomNumberGenerator) -> LayerTile:
	if self.layers.has(BiomeLayer.LayerType.GROUND):
		return self.layers[BiomeLayer.LayerType.GROUND]["layer"].get_random_tile(rng)
	return null

func get_random_prop(rng: RandomNumberGenerator) -> LayerTile:
	var selected_layer: BiomeLayer

	# 1) Biome-wide sparsity gate
	if rng.randf() > pow(self.biome_density, RNG_POWER):
		return null

	# 2) Build candidates = non-ground layers only
	var candidates: Array = []           # [{ "layer": BiomeLayer, "weight": float }, ...]
	var total_weight := 0.0
	for entry in self.layers.values():
		var L: BiomeLayer = entry["layer"]
		if L.get_layer_type() == BiomeLayer.LayerType.GROUND:
			continue
		candidates.append(entry)
		total_weight += float(entry["weight"])

	if total_weight <= 0.0:
		return null

	# 3) Pick a candidate layer by its weight
	var choice_point := rng.randf() * total_weight
	var running_total := 0.0
	for entry in candidates:
		running_total += float(entry["weight"])
		if choice_point < running_total:
			selected_layer = entry["layer"]
			break

	# 4) Ask that layer for a tile (layer's own density applies inside)
	return selected_layer.get_random_tile(rng) if selected_layer != null else null




# placeholder for getting temp and converting if needed
# func get_temp() -> float:
#    if user_data.get("temp_unit", "farenheit") == "celcius":
#       return (self.temperature - 32.0) * 5.0 / 9.0
#    else:
#       return self.temperature
