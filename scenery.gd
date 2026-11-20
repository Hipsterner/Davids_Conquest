extends RefCounted

const Hex := preload("res://rules/hex.gd")

const MOUNTAIN_LEVEL := 0.8
const FOREST_LEVEL := 0.12
const RIVER_COUNT := 3
const RIVER_SPACING := 9.0
const MIN_RIVER_CELLS := 5
const MAX_RIVER_CELLS := 40


static func generate(cells: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var heights := _heights(cells, rng)
	var mountains := {}
	for cell: Vector2i in cells:
		if heights[cell] >= MOUNTAIN_LEVEL:
			mountains[cell] = true
	return {
		"heights": heights,
		"mountains": mountains,
		"forests": _forests(cells, mountains, rng),
		"rivers": _rivers(cells, heights),
	}


static func _sea_neighbor(cell: Vector2i, cells: Dictionary) -> Vector2i:
	for next in Hex.neighbors(cell):
		if not cells.has(next):
			return next
	return cell


static func _heights(cells: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi() % 100000
	noise.frequency = 0.11
	var depth := {}
	var open: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _sea_neighbor(cell, cells) != cell:
			depth[cell] = 0
			open.append(cell)
	var deepest := 1
	var index := 0
	while index < open.size():
		var cell := open[index]
		index += 1
		for next in Hex.neighbors(cell):
			if cells.has(next) and not depth.has(next):
				var steps: int = depth[cell] + 1
				depth[next] = steps
				deepest = maxi(deepest, steps)
				open.append(next)
	var heights := {}
	var highest := 0.001
	for cell: Vector2i in cells:
		var inland: float = float(depth[cell]) / deepest
		var height := 0.6 * inland + 0.4 * (noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5)
		heights[cell] = height
		highest = maxf(highest, height)
	for cell: Vector2i in cells:
		heights[cell] /= highest
	return heights


static func _forests(cells: Dictionary, mountains: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi() % 100000
	noise.frequency = 0.16
	var forests := {}
	for cell: Vector2i in cells:
		if not mountains.has(cell) and noise.get_noise_2d(cell.x, cell.y) > FOREST_LEVEL:
			forests[cell] = true
	return forests


static func _rivers(cells: Dictionary, heights: Dictionary) -> Array:
	var ranked := cells.keys()
	ranked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return heights[a] > heights[b])
	var sources: Array[Vector2i] = []
	for cell: Vector2i in ranked:
		if sources.size() == RIVER_COUNT:
			break
		var spaced := true
		for other in sources:
			if Hex.center(cell).distance_to(Hex.center(other)) < RIVER_SPACING:
				spaced = false
		if spaced:
			sources.append(cell)
	var rivers := []
	var wet := {}
	for source in sources:
		var path := _flow(source, cells, heights, wet)
		if path.size() >= MIN_RIVER_CELLS:
			rivers.append(path)
	return rivers


static func _flow(source: Vector2i, cells: Dictionary, heights: Dictionary, wet: Dictionary) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var seen := {}
	var cell := source
	while path.size() < MAX_RIVER_CELLS:
		path.append(Hex.center(cell))
		if wet.has(cell):
			break
		seen[cell] = true
		var sea := _sea_neighbor(cell, cells)
		if sea != cell:
			path.append(Hex.center(sea))
			break
		var lowest := cell
		for next in Hex.neighbors(cell):
			if not seen.has(next) and (lowest == cell or heights[next] < heights[lowest]):
				lowest = next
		if lowest == cell:
			break
		cell = lowest
	for visited: Vector2i in seen:
		wet[visited] = true
	return path
