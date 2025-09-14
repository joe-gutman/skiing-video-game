extends RefCounted
class_name GameWorld


# Voronoi Biome Controls
var voronoi_frequency: float = 1.0 / 100.0  # region size (lower = bigger regions)
var voronoi_distance_fn: int = FastNoiseLite.DISTANCE_EUCLIDEAN
var warp_amp: float = 100.0                 # how strong domain warp is
var warp_frequency: float = 1.0 / 400.0     # how wiggly borders are

# Corridor blending
var border_threshold: float = 0.1           # near borders → allow blending

# Slope frequency
var slope_frequency: float = 0.1


var biome_voronoi := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()

var name: String
var biomes: Dictionary
var slopes: Dictionary
var slope_instances: Array
var rng: RandomNumberGenerator
var seed: int


func _init(name: String, seed: int = 0) -> void:
	self.name = name
	self.seed = seed
	self.biomes = {}
	self.slopes = {}
	self.slope_instances = []
	rng = RandomNumberGenerator.new()

	# init warp noise
	warp_noise.seed = int(rng.seed) ^ 0x5a5a
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = warp_frequency

	# Voronoi noise for biome regions
	biome_voronoi.seed = self.seed
	biome_voronoi.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_voronoi.cellular_distance_function = voronoi_distance_fn
	biome_voronoi.frequency = voronoi_frequency

	if seed == 0:
		rng.randomize()
		self.seed = rng.seed
	else:
		rng.seed = seed

func add_biome(
	biome: WorldBiome,
	weight: float = 1.0,
	scale: float = 1.0,
	octaves: int = 1,
	persistence: float = 0.5,
	lacunarity: float = 2.0,
	width: float = 1.0,
	length: float = 1.0
) -> void:
	if not (biome is WorldBiome):
		push_error("Biome must be a WorldBiome type but got %s." % typeof(biome))
		return

	if self.biomes.has(biome.name):
		push_error("Biome with name '%s' already exists." % biome.name)
		return

	# Keep noise data for local variation inside biomes
	var noise := _make_noise(scale, octaves, persistence, lacunarity)

	self.biomes[biome.name] = {
		"biome": biome,
		"noise": noise,
		"weight": weight,
		"width": width,
		"length": length,
		"scale": scale,
		"octaves": octaves,
		"persistence": persistence,
		"lacunarity": lacunarity
	}

func add_biomes(biomes_list: Array) -> void:
	for biome in biomes_list:
		add_biome(biome)

func get_biome(biome_name: String) -> WorldBiome:
	var biome_data = self.biomes.get(biome_name, null)
	if biome_data:
		return biome_data["biome"]
	return null

func get_biomes() -> Array:
	var biome_array: Array = []
	for biome_data in self.biomes.values():
		biome_array.append(biome_data["biome"])
	return biome_array

func get_biome_at(cell: Vector2i) -> WorldBiome:
	if biomes.is_empty():
		return null

	var x: float = cell.x
	var y: float = cell.y

	# Warp input
	if warp_amp > 0.0:
		var wx: float = warp_noise.get_noise_2d(x, y)
		var wy: float = warp_noise.get_noise_2d(x + 1337.0, y - 7331.0)
		x += wx * warp_amp
		y += wy * warp_amp

	# --- Step 1: approximate nearest & second-nearest distances ---
	var distances: Array = []
	for dx in [-5, 0, 5]:
		for dy in [-5, 0, 5]:
			var d = biome_voronoi.get_noise_2d(x + dx, y + dy)
			distances.append(d)
	distances.sort()
	var d1: float = distances[0]
	var d2: float = distances[1]

	# --- Step 2: stable biome IDs ---
	var cell_id1: int = _hash_cell(int(floor(x / 100.0)), int(floor(y / 100.0)))
	var idx1: int = cell_id1 % biomes.size()

	var cell_id2: int = _hash_cell(int(floor(x / 100.0)) + 1, int(floor(y / 100.0)) + 1)
	var idx2: int = cell_id2 % biomes.size()

	var biome1: WorldBiome = biomes.values()[idx1]["biome"]
	var biome2: WorldBiome = biomes.values()[idx2]["biome"]

	# --- Step 3: normalized ratio ---
	var ratio: float = d1 / max((d1 + d2), 0.0001)

	if ratio > 0.5 + border_threshold:
		return biome1
	elif ratio < 0.5 - border_threshold:
		return biome2
	else:
		# --- Step 4: probabilistic flip inside band ---
		var w1: float = 1.0 / max(d1, 0.001)
		var w2: float = 1.0 / max(d2, 0.001)
		var total: float = w1 + w2
		var p1: float = w1 / total

		if rng.randf() < p1:
			return biome1
		else:
			return biome2

func _hash_cell(x: int, y: int) -> int:
	# Simple hash for stable biome assignment per Voronoi cell
	return int(((x * 73856093) ^ (y * 19349663) ^ seed) & 0x7fffffff)

func add_slope(slope: WorldSlope) -> void:
	if not (slope is WorldSlope):
		push_error("Slope must be a WorldSlope type but got %s." % typeof(slope))
		return

	if self.slopes.has(slope.name):
		push_error("Slope with name '%s' already exists." % slope.name)
		return

	self.slopes[slope.name] = slope

func get_slope(slope_name: String) -> WorldSlope:
	if self.slopes.has(slope_name):
		return self.slopes[slope_name]
	return null

func get_random_slope() -> WorldSlope:
	var total_weight := 0.0
	for slope_def in slopes.values():
		total_weight += slope_def.weight

	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	for slope_def in slopes.values():
		roll -= slope_def.weight
		if roll <= 0.0:
			return slope_def
	return null

func get_slopes() -> Array:
	return self.slopes.values()

func _make_noise(
	scale: float = 1.0,
	octaves: int = 1,
	persistence: float = 0.5,
	lacunarity: float = 2.0
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 1.0 / scale
	noise.fractal_octaves = octaves
	noise.fractal_gain = persistence
	noise.fractal_lacunarity = lacunarity
	return noise

func _normalize_noise(noise: FastNoiseLite, cell: Vector2i) -> float:
	var raw_value: float = noise.get_noise_2d(cell.x, cell.y)
	return (raw_value + 1.0) * 0.5
