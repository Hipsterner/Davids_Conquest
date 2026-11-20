extends RefCounted

const SQRT3 := 1.7320508
const DIRECTIONS_EVEN_ROW: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1),
]
const DIRECTIONS_ODD_ROW: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]


static func neighbor(cell: Vector2i, direction: int) -> Vector2i:
	if (cell.y & 1) == 1:
		return cell + DIRECTIONS_ODD_ROW[direction]
	return cell + DIRECTIONS_EVEN_ROW[direction]


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in 6:
		result.append(neighbor(cell, direction))
	return result


static func center(cell: Vector2i) -> Vector2:
	return Vector2(SQRT3 * (cell.x + 0.5 * (cell.y & 1)), 1.5 * cell.y)
