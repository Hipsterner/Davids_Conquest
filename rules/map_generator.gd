extends RefCounted

const Hex := preload("res://rules/hex.gd")
const Region := preload("res://rules/region.gd")

const COLS := 34
const ROWS := 36
const REGION_COUNT := 22
const SEED_ATTEMPTS := 20
const NAME_STARTS: Array[String] = [
	"Eld", "Thorn", "Raven", "Storm", "Wolf", "Iron", "Ash", "Dun", "Glim", "Hollow", "Frost", "Amber",
	"Mist", "Oak", "Grim", "Silver", "Bram", "Wyrm", "Stag", "High", "Black", "Gold", "Red", "Elm",
]
const NAME_ENDS: Array[String] = [
	"mere", "hold", "wick", "fell", "moor", "garde", "haven", "reach", "vale", "ford", "crest", "watch",
]


static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var land := _largest_landmass(_land_cells(rng))
	var cells := _grow_regions(land, _pick_origins(land, rng), rng)
	var regions := _build_regions(cells, rng)
	return {"cells": cells, "regions": regions, "starts": _pick_starts(regions)}


static func _land_cells(rng: RandomNumberGenerator) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi() % 100000
	noise.frequency = 0.08
	var land := {}
	for row in ROWS:
		for col in COLS:
			var x := (col + 0.5 * (row & 1)) / (COLS - 0.5) * 2.0 - 1.0
			var y := float(row) / (ROWS - 1) * 2.0 - 1.0
			var edge := pow(pow(absf(x), 3.0) + pow(absf(y), 3.0), 1.0 / 3.0)
			if 1.0 - edge + noise.get_noise_2d(col, row) * 0.3 > 0.12:
				land[Vector2i(col, row)] = true
	return land


static func _largest_landmass(land: Dictionary) -> Dictionary:
	var best := {}
	var seen := {}
	for origin: Vector2i in land:
		if seen.has(origin):
			continue
		var mass := {origin: true}
		var open: Array[Vector2i] = [origin]
		seen[origin] = true
		while not open.is_empty():
			for next in Hex.neighbors(open.pop_back()):
				if land.has(next) and not seen.has(next):
					seen[next] = true
					mass[next] = true
					open.append(next)
		if mass.size() > best.size():
			best = mass
	return best


static func _pick_origins(land: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var candidates := land.keys()
	var origins: Array[Vector2i] = [candidates[rng.randi_range(0, candidates.size() - 1)]]
	while origins.size() < REGION_COUNT:
		var best := Vector2i.ZERO
		var best_distance := -1.0
		for attempt in SEED_ATTEMPTS:
			var candidate: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			var distance := INF
			for origin in origins:
				distance = minf(distance, Hex.center(candidate).distance_to(Hex.center(origin)))
			if distance > best_distance:
				best_distance = distance
				best = candidate
		origins.append(best)
	return origins


static func _grow_regions(land: Dictionary, origins: Array[Vector2i], rng: RandomNumberGenerator) -> Dictionary:
	var cells := {}
	var frontiers: Array = []
	for index in origins.size():
		cells[origins[index]] = index
		frontiers.append([origins[index]])
	var growing := true
	while growing:
		growing = false
		for index in frontiers.size():
			var frontier: Array = frontiers[index]
			if frontier.is_empty():
				continue
			growing = true
			var pick := rng.randi_range(0, frontier.size() - 1)
			var cell: Vector2i = frontier[pick]
			frontier[pick] = frontier[-1]
			frontier.pop_back()
			for next in Hex.neighbors(cell):
				if land.has(next) and not cells.has(next):
					cells[next] = index
					frontier.append(next)
	return cells


static func _build_regions(cells: Dictionary, rng: RandomNumberGenerator) -> Array:
	var regions := []
	var used_names := {}
	for index in REGION_COUNT:
		var region := Region.new()
		region.id = index
		region.name = _unique_name(rng, used_names)
		regions.append(region)
	for cell: Vector2i in cells:
		var region: Region = regions[cells[cell]]
		region.cells.append(cell)
		for next in Hex.neighbors(cell):
			var other: int = cells.get(next, region.id)
			if other != region.id and not region.neighbors.has(other):
				region.neighbors.append(other)
	for region: Region in regions:
		region.center = _center_cell(region.cells)
	return regions


static func _unique_name(rng: RandomNumberGenerator, used_names: Dictionary) -> String:
	while true:
		var candidate := (
			NAME_STARTS[rng.randi_range(0, NAME_STARTS.size() - 1)]
			+ NAME_ENDS[rng.randi_range(0, NAME_ENDS.size() - 1)]
		)
		if not used_names.has(candidate):
			used_names[candidate] = true
			return candidate
	return ""


static func _center_cell(region_cells: Array[Vector2i]) -> Vector2i:
	var centroid := Vector2.ZERO
	for cell in region_cells:
		centroid += Hex.center(cell)
	centroid /= region_cells.size()
	var best := region_cells[0]
	for cell in region_cells:
		if Hex.center(cell).distance_to(centroid) < Hex.center(best).distance_to(centroid):
			best = cell
	return best


static func _pick_starts(regions: Array) -> Array:
	var south_west: Region = regions[0]
	var north_east: Region = regions[0]
	for region: Region in regions:
		if _corner_score(region) > _corner_score(south_west):
			south_west = region
		if _corner_score(region) < _corner_score(north_east):
			north_east = region
	return [south_west.id, north_east.id]


static func _corner_score(region: Region) -> float:
	var position := Hex.center(region.center)
	return position.y - position.x
