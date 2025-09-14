extends RefCounted
class_name GameWorld

# Biome Voronoi control:
var biome_voronoi := FastNoiseLite.new()

# Noise distortion (warp Voronoi to look like clouds):
var warp_amp := 100.0
var warp_noise := FastNoiseLite.new()

var slope_frequency: float = 0.1

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

	# init warp noise (simplex used to distort Voronoi)
	warp_noise.seed = int(rng.seed) ^ 0x5a5a
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = 1.0 / 400.0

	# Voronoi noise for biome regions
	biome_voronoi.seed = self.seed
	biome_voronoi.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_voronoi.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	biome_voronoi.frequency = 1.0 / 100.0  # region size

	if seed == 0:
		rng.randomize()
		self.seed = rng.seed
	else:
		rng.seed = seed


# Add biomes to dictionary (still used for indexing + props)
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

	# Keep noise data for local variation if you want to use it inside biomes
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

	var best_biome: WorldBiome = null
	var best_val := 999999.0
	var i := 0

	for biome_data in biomes.values():
		var biome: WorldBiome = biome_data["biome"]

		# Warp input for organic shapes
		var x: float = cell.x
		var y: float = cell.y
		if warp_amp > 0.0:
			var wx := warp_noise.get_noise_2d(x, y)
			var wy := warp_noise.get_noise_2d(x + 1337.0, y - 7331.0)
			x += wx * warp_amp
			y += wy * warp_amp

		# Sample Voronoi field for this biome (offset per biome so regions differ)
		var n := biome_voronoi.get_noise_2d(x + i * 1000.0, y - i * 2000.0)

		# Lower = closer to Voronoi cell center
		if n < best_val:
			best_val = n
			best_biome = biome

		i += 1

	return best_biome

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
