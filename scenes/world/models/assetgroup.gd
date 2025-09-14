extends RefCounted
class_name AssetGroup

var name: String
var density: float
var weight: float
var assets: Dictionary  # { asset_name: { "asset": WorldAsset, "weight": float }, ... }

func _init(name: String, density: float = 1.0, weight: float = 1.0) -> void:
	self.name = name
	self.density = clamp(density, 0.0, 1.0)
	self.weight = max(weight, 0.0)
	self.assets = {}

func add_asset(asset: WorldAsset, weight: float) -> void:
	if not (asset is WorldAsset):
		push_error("Asset must be a WorldAsset type but got %s." % typeof(asset))
		return

	if assets.has(asset.name):
		push_error("Asset with name '%s' already exists." % asset.name)
		return

	if weight < 0.0:
		push_error("Weight for %s cannot be negative" % asset.name)
		return

	# Store validated entry
	assets[asset.name] = {
		"asset": asset,
		"weight": weight
	}

func add_assets(asset_list: Array) -> void:
	for entry in asset_list:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Each entry in add_assets must be a dictionary {asset: WorldAsset, weight: float}")
			continue

		if not entry.has("asset") or not (entry["asset"] is WorldAsset):
			push_error("Asset entry missing valid 'asset'")
			continue

		if not entry.has("weight") or typeof(entry["weight"]) != TYPE_FLOAT:
			push_error("Asset entry for %s missing valid 'weight'" % str(entry.get("asset")))
			continue

		add_asset(entry["asset"], entry["weight"])

func get_random_asset(rng: RandomNumberGenerator) -> WorldAsset:
	# Step 1: Density check
	if rng.randf() > self.density:
		return null

	# Step 2: Weighted pick
	var total_weight := 0.0
	for asset_data in assets.values():
		total_weight += asset_data["weight"]

	if total_weight <= 0.0:
		return null

	var choice_point := rng.randf() * total_weight
	var running_total := 0.0
	var last_asset: WorldAsset = null

	# Deterministic iteration order
	var keys = assets.keys()
	keys.sort()

	for key in keys:
		var asset_data = assets[key]
		last_asset = asset_data["asset"]
		running_total += asset_data["weight"]
		if choice_point < running_total:
			return asset_data["asset"]

	# Fallback
	return last_asset
