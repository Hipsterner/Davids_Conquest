extends Node2D

signal region_clicked(region_id: int, button: int, with_shift: bool)
signal region_hovered(region_id: int)

const Hex := preload("res://rules/hex.gd")
const GameState := preload("res://rules/game_state.gd")
const Region := preload("res://rules/region.gd")

const SEA := Rect2(200, 0, 880, 800)
const AREA := Rect2(200, 72, 880, 728)
const HEX_SIZE := 13.6
const SQUASH := 0.8
const CLIFF_HEIGHT := 14.0
const PLAYER_COLORS: Array[Color] = [Color("c9433b"), Color("3b74cf")]
const BARBARIAN_COLOR := Color("5c3a1e")
const CUT_OFF_TINT := Color("a39c92")
const SEA_DEEP := Color("17435e")
const SEA_MID := Color("2f8199")
const SHALLOWS := Color("7fd6cc")
const CLIFF_LIGHT := Color("7a5f40")
const CLIFF_DARK := Color("4a3826")
const SAND := Color("e3d39c")
const GRASS_LOW := Color("b4cb78")
const GRASS_HIGH := Color("7dab58")
const FOREST := Color("568a4c")
const HIGHLAND := Color("a8a07c")
const ROCK := Color("8f8b7f")
const WAVE_COUNT := 46
const DIE_SIZE := 38.0
const DIE_GAP := 22.0
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}
const INK := Color("2b2118")
const STONE := Color("ddd6c4")
const GOLD := Color("ffd75e")
const BATTLE_COLOR := Color("ff4d3d")
const PLAGUE_COLOR := Color("a6e22e")
const UNREST_COLOR := Color("ff9d2e")

var state: GameState
var cells := {}
var selected := -1
var battle_target := -1
var burning := false
var hit_region := -1
var hint_region := -1
var dice_region := -1
var dice_rolls: Array[int] = [0, 0]
var dice_colors: Array[Color] = [Color.WHITE, Color.WHITE]
var dice_winner := -1
var dice_tumbling := false
var hovered := -1
var origin := Vector2.ZERO
var corners: Array[Vector2] = []
var natural := {}
var decorations: Array[Dictionary] = []
var rivers: Array[PackedVector2Array] = []
var coast: Array[Vector2] = []
var waves: Array[Vector2] = []
var font := SystemFont.new()


func _ready() -> void:
	font.font_names = PackedStringArray(["Palatino", "Georgia"])
	font.font_weight = 700
	for index in 6:
		var angle := deg_to_rad(60.0 * index - 30.0)
		corners.append(Vector2(cos(angle), sin(angle) * SQUASH) * HEX_SIZE)


func show_map(new_state: GameState, new_cells: Dictionary, scenery: Dictionary) -> void:
	state = new_state
	cells = new_cells
	hovered = -1
	origin = Vector2.ZERO
	var first: Vector2i = cells.keys()[0]
	var bounds := Rect2(_position_of(first), Vector2.ZERO)
	for cell: Vector2i in cells:
		bounds = bounds.expand(_position_of(cell))
	origin = AREA.get_center() - bounds.get_center()
	_prepare_scenery(scenery)
	queue_redraw()


func _prepare_scenery(scenery: Dictionary) -> void:
	natural.clear()
	decorations.clear()
	rivers.clear()
	coast.clear()
	waves.clear()
	for cell: Vector2i in cells:
		var at := _position_of(cell)
		var is_forest: bool = scenery.forests.has(cell)
		natural[cell] = _natural_color(scenery.heights[cell], is_forest)
		if Hex.neighbors(cell).any(func(next: Vector2i) -> bool: return not cells.has(next)):
			coast.append(at)
		var from_badge := at - _position_of(state.regions[cells[cell]].center)
		if absf(from_badge.x) < 34 and from_badge.y > -48 and from_badge.y < 22:
			continue
		if scenery.mountains.has(cell):
			decorations.append({"mountain": true, "at": at, "size": lerpf(0.85, 1.4, scenery.heights[cell])})
		elif is_forest:
			decorations.append({"mountain": false, "at": at, "size": 1.0})
	decorations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at.y < b.at.y)
	for path: Array in scenery.rivers:
		var line := PackedVector2Array()
		for point: Vector2 in path:
			line.append(origin + Vector2(point.x, point.y * SQUASH) * HEX_SIZE)
		rivers.append(_smooth(_smooth(line)))
	var scatter := RandomNumberGenerator.new()
	scatter.seed = cells.size()
	while waves.size() < WAVE_COUNT:
		var point := SEA.position + Vector2(scatter.randf_range(20, SEA.size.x - 20), scatter.randf_range(20, SEA.size.y - 20))
		if region_at(point) == -1:
			waves.append(point)


func _natural_color(height: float, is_forest: bool) -> Color:
	var color := SAND.lerp(GRASS_LOW, smoothstep(0.02, 0.2, height))
	color = color.lerp(GRASS_HIGH, smoothstep(0.2, 0.5, height))
	color = color.lerp(HIGHLAND, smoothstep(0.55, 0.74, height))
	color = color.lerp(ROCK, smoothstep(0.74, 1.0, height))
	return color.lerp(FOREST, 0.7) if is_forest else color


func _smooth(line: PackedVector2Array) -> PackedVector2Array:
	if line.size() < 3:
		return line
	var result := PackedVector2Array([line[0]])
	for index in line.size() - 1:
		result.append(line[index].lerp(line[index + 1], 0.25))
		result.append(line[index].lerp(line[index + 1], 0.75))
	result.append(line[-1])
	return result


func show_dice(
	region_id: int, attack_roll: int, defense_roll: int, attack_color: Color, defense_color: Color, winner: int
) -> void:
	dice_region = region_id
	dice_rolls = [attack_roll, defense_roll]
	dice_colors = [attack_color, defense_color]
	dice_winner = winner
	dice_tumbling = false
	queue_redraw()


func tumble_dice() -> void:
	dice_rolls = [randi_range(1, 6), randi_range(1, 6)]
	dice_winner = -1
	dice_tumbling = true
	queue_redraw()


func hide_dice() -> void:
	dice_region = -1
	queue_redraw()


func badge_position(region_id: int) -> Vector2:
	return _position_of(state.regions[region_id].center)


func dice_anchor(region_id: int) -> Vector2:
	return badge_position(region_id) + Vector2(0, -76.0 if state.starts.has(region_id) else -46.0)


func region_at(point: Vector2) -> int:
	var local := (point - origin) / HEX_SIZE
	local.y /= SQUASH
	var row_guess := roundi(local.y / 1.5)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for row in range(row_guess - 1, row_guess + 2):
		var col_guess := roundi(local.x / Hex.SQRT3 - 0.5 * (row & 1))
		for col in range(col_guess - 1, col_guess + 2):
			var distance := Hex.center(Vector2i(col, row)).distance_squared_to(local)
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(col, row)
	return cells.get(best, -1)


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseMotion:
		var region_id := region_at(make_input_local(event).position)
		if region_id != hovered:
			hovered = region_id
			region_hovered.emit(region_id)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var button: int = MOUSE_BUTTON_RIGHT if event.ctrl_pressed or event.meta_pressed else event.button_index
		region_clicked.emit(region_at(make_input_local(event).position), button, event.shift_pressed)


func _draw() -> void:
	if state == null:
		return
	_draw_sea()
	for cell: Vector2i in cells:
		_draw_hex(_position_of(cell) + Vector2(7, CLIFF_HEIGHT + 9), Color(0, 0, 0, 0.16))
	for cell: Vector2i in cells:
		_draw_hex(_position_of(cell) + Vector2(0, CLIFF_HEIGHT), CLIFF_DARK)
	for cell: Vector2i in cells:
		_draw_hex(_position_of(cell) + Vector2(0, CLIFF_HEIGHT * 0.5), CLIFF_LIGHT)
	for cell: Vector2i in cells:
		_draw_hex(_position_of(cell), _cell_color(cell, state.regions[cells[cell]]))
	for river in rivers:
		draw_polyline(river, Color("2b7896"), 6.0, true)
		draw_polyline(river, Color("86d6e6"), 3.0, true)
	for cell: Vector2i in cells:
		_draw_borders(cell)
	for decoration in decorations:
		if decoration.mountain:
			_draw_mountain(decoration.at, decoration.size)
		else:
			_draw_trees(decoration.at)
	if burning and battle_target != -1:
		_draw_fire(state.regions[battle_target])
	if state.winner == GameState.NEUTRAL:
		_draw_realm_glow(state.current_player)
	for region: Region in state.regions:
		if region.owner != GameState.NEUTRAL and region.unrest > 0:
			_draw_outline(region, UNREST_COLOR, 2.5)
	for event in state.events:
		_draw_outline(state.regions[event.region], PLAGUE_COLOR if event.kind == "plague" else UNREST_COLOR, 4.0)
	if battle_target != -1:
		_draw_outline(state.regions[battle_target], BATTLE_COLOR, 4.0)
	elif selected != -1:
		var source: Region = state.regions[selected]
		var leads := state.generals[state.current_player] == selected
		for region: Region in state.regions:
			if source.neighbors.has(region.id) and (leads or region.owner == source.owner):
				_draw_outline(region, Color(1, 1, 1, 0.85), 2.0)
	if selected != -1:
		_draw_outline(state.regions[selected], GOLD, 3.5)
	if hint_region != -1:
		_draw_outline(state.regions[hint_region], Color.WHITE, 7.0)
		_draw_outline(state.regions[hint_region], GOLD, 4.0)
	for region: Region in state.regions:
		_draw_badge(region)
	_draw_dice()


func _draw_dice() -> void:
	if dice_region == -1 or dice_rolls[0] == 0:
		return
	var anchor := dice_anchor(dice_region)
	for index in 2:
		var center := anchor + Vector2((index - 0.5) * (DIE_SIZE + DIE_GAP), 0)
		var lost := dice_winner != -1 and dice_winner != index
		var face := StyleBoxFlat.new()
		face.bg_color = dice_colors[index].darkened(0.45) if lost else dice_colors[index]
		face.border_color = GOLD if dice_winner == index else INK
		face.set_border_width_all(4 if dice_winner == index else 2)
		face.set_corner_radius_all(7)
		face.shadow_color = Color(0, 0, 0, 0.4)
		face.shadow_size = 5
		if dice_tumbling:
			draw_set_transform(center + Vector2(randf_range(-4, 4), randf_range(-4, 4)), randf_range(-0.4, 0.4))
		else:
			draw_set_transform(center)
		draw_style_box(face, Rect2(-Vector2.ONE * DIE_SIZE / 2, Vector2.ONE * DIE_SIZE))
		for pip: Vector2 in PIPS[dice_rolls[index]]:
			draw_circle(pip * 10.0, 3.6, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if not dice_tumbling and dice_rolls[0] == dice_rolls[1]:
		draw_string_outline(font, anchor + Vector2(-20, 9), "=", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, 5, INK)
		draw_string(font, anchor + Vector2(-20, 9), "=", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color.WHITE)


func _position_of(cell: Vector2i) -> Vector2:
	var center := Hex.center(cell)
	return origin + Vector2(center.x, center.y * SQUASH) * HEX_SIZE


func _cell_color(cell: Vector2i, region: Region) -> Color:
	var color: Color = natural[cell]
	if region.owner != GameState.NEUTRAL:
		var relief := (color.get_luminance() - 0.6) * 0.9
		color = PLAYER_COLORS[region.owner]
		if not region.supplied:
			color = color.lerp(CUT_OFF_TINT, 0.6)
		if region.owner != state.current_player:
			color = color.darkened(0.3)
		color = color.lightened(relief) if relief > 0 else color.darkened(-relief)
	if region.id == selected:
		return color.lightened(0.2)
	if region.id == hovered:
		return color.lightened(0.1)
	return color


func _draw_sea() -> void:
	var center := AREA.get_center()
	var rim := [SEA.position, Vector2(SEA.end.x, SEA.position.y), SEA.end, Vector2(SEA.position.x, SEA.end.y)]
	for index in 4:
		draw_polygon(
			PackedVector2Array([rim[index], rim[(index + 1) % 4], center]),
			PackedColorArray([SEA_DEEP, SEA_DEEP, SEA_MID])
		)
	for wave in waves:
		draw_arc(wave, 8.0, PI * 0.15, PI * 0.85, 8, Color(1, 1, 1, 0.13), 1.5, true)
	for at in coast:
		_draw_hex(at, Color(SHALLOWS, 0.07), 2.6)
	for at in coast:
		_draw_hex(at, Color(SHALLOWS, 0.1), 1.7)


func _draw_mountain(at: Vector2, size: float) -> void:
	var peak := at + Vector2(0, -15) * size
	var left := at + Vector2(-11, 6) * size
	var right := at + Vector2(11, 6) * size
	draw_colored_polygon(PackedVector2Array([left, peak, right]), Color("a09c90"))
	draw_colored_polygon(PackedVector2Array([peak, right, at + Vector2(2, 6) * size]), Color("726e66"))
	draw_colored_polygon(PackedVector2Array([peak, peak.lerp(left, 0.34), peak.lerp(right, 0.34)]), Color("f6f3ea"))
	draw_polyline(PackedVector2Array([left, peak, right]), Color(INK, 0.55), 1.2, true)


func _draw_trees(at: Vector2) -> void:
	for offset: Vector2 in [Vector2(-5, 3), Vector2(4, -1)]:
		var base := at + offset
		draw_colored_polygon(
			PackedVector2Array([base + Vector2(-4.5, 2), base + Vector2(0, -9), base + Vector2(4.5, 2)]), Color("3f7244")
		)
		draw_colored_polygon(
			PackedVector2Array([base + Vector2(0, -9), base + Vector2(4.5, 2), base + Vector2(0.5, 2)]), Color("2e5a37")
		)


func _draw_hex(center: Vector2, color: Color, scale_factor := 1.0) -> void:
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner * scale_factor)
	draw_colored_polygon(points, color)


func _draw_borders(cell: Vector2i) -> void:
	var center := _position_of(cell)
	var region_id: int = cells[cell]
	for direction in 6:
		var other: int = cells.get(Hex.neighbor(cell, direction), -1)
		if other == -1:
			draw_line(center + corners[direction], center + corners[(direction + 1) % 6], INK, 2.5, true)
		elif other > region_id:
			draw_line(center + corners[direction], center + corners[(direction + 1) % 6], Color(INK, 0.7), 2.0, true)


func _draw_outline(region: Region, color: Color, width: float) -> void:
	for cell in region.cells:
		var center := _position_of(cell)
		for direction in 6:
			if cells.get(Hex.neighbor(cell, direction), -1) != region.id:
				draw_line(center + corners[direction], center + corners[(direction + 1) % 6], color, width, true)


func _draw_fire(region: Region) -> void:
	for cell in region.cells:
		_draw_hex(_position_of(cell), Color(1.0, 0.35, 0.05, randf_range(0.15, 0.45)))
	for flame in 8:
		var base := _position_of(region.cells[randi() % region.cells.size()])
		var height := randf_range(14.0, 26.0)
		draw_colored_polygon(
			PackedVector2Array([
				base + Vector2(0, -height), base + Vector2(6, -3), base + Vector2(4, 4), base + Vector2(-4, 4),
				base + Vector2(-6, -3),
			]),
			Color("ff7a1a")
		)
		draw_colored_polygon(
			PackedVector2Array([
				base + Vector2(0, -height * 0.5), base + Vector2(3, -1), base + Vector2(0, 3), base + Vector2(-3, -1),
			]),
			Color("ffe066")
		)


func _draw_realm_glow(player: int) -> void:
	var glow := PLAYER_COLORS[player].lightened(0.5)
	for cell: Vector2i in cells:
		var region: Region = state.regions[cells[cell]]
		if region.owner != player:
			continue
		var center := _position_of(cell)
		for direction in 6:
			var other: int = cells.get(Hex.neighbor(cell, direction), -1)
			if other == -1 or state.regions[other].owner != player:
				draw_line(center + corners[direction], center + corners[(direction + 1) % 6], glow, 3.0, true)


func _draw_badge(region: Region) -> void:
	var center := _position_of(region.center)
	var color := BARBARIAN_COLOR
	if region.owner != GameState.NEUTRAL:
		color = PLAYER_COLORS[region.owner].darkened(0.35)
	if state.starts.has(region.id):
		_draw_castle(center + Vector2(0, -15), PLAYER_COLORS[state.starts.find(region.id)])
	if state.events.any(func(event: Dictionary) -> bool: return event.region == region.id and event.kind == "plague"):
		draw_circle(center, 17.0, PLAGUE_COLOR)
	if region.owner != GameState.NEUTRAL and region.unrest > 0:
		var warning := PackedVector2Array([
			center + Vector2(-27, -5), center + Vector2(-11, -5), center + Vector2(-19, -21), center + Vector2(-27, -5),
		])
		draw_colored_polygon(warning, UNREST_COLOR)
		draw_polyline(warning, INK, 1.5, true)
		draw_string(font, center + Vector2(-29, -7), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 11, INK)
	draw_circle(center + Vector2(0, 2.5), 14.0, Color(0, 0, 0, 0.3))
	draw_circle(center, 13.0, INK)
	draw_circle(center, 11.0, color)
	draw_string(font, center + Vector2(-20, 5.5), str(region.soldiers), HORIZONTAL_ALIGNMENT_CENTER, 40, 15, Color.WHITE)
	if region.owner != GameState.NEUTRAL and state.generals[region.owner] == region.id:
		_draw_general(center + Vector2(15, 4), PLAYER_COLORS[region.owner])
	if region.id == hit_region:
		draw_string_outline(font, center + Vector2(-60, 7), "−1", HORIZONTAL_ALIGNMENT_RIGHT, 44, 20, 5, INK)
		draw_string(font, center + Vector2(-60, 7), "−1", HORIZONTAL_ALIGNMENT_RIGHT, 44, 20, Color("ff6b5a"))
	for event in state.events:
		if event.region == region.id:
			var news := "Revolt" if event.kind == "revolt" else "Plague −%d" % event.lost
			var news_color := UNREST_COLOR if event.kind == "revolt" else Color("dcff8a")
			draw_string_outline(font, center + Vector2(-60, 44), news, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 7, INK)
			draw_string(font, center + Vector2(-60, 44), news, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, news_color)
	if region.recovering > 0:
		draw_string_outline(font, center + Vector2(-20, 27), "+0", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, 4, INK)
		draw_string(font, center + Vector2(-20, 27), "+0", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, Color.WHITE)


func _draw_castle(base: Vector2, flag_color: Color) -> void:
	var walls := Rect2(base + Vector2(-13, -12), Vector2(26, 12))
	draw_rect(walls, STONE)
	draw_rect(walls, INK, false, 1.5)
	for offset: float in [-13.0, -3.5, 6.0]:
		var tower := Rect2(base + Vector2(offset, -19), Vector2(7, 7))
		draw_rect(tower, STONE)
		draw_rect(tower, INK, false, 1.5)
	draw_line(base + Vector2(0, -19), base + Vector2(0, -31), INK, 1.5)
	draw_colored_polygon(
		PackedVector2Array([base + Vector2(0, -31), base + Vector2(10, -27.5), base + Vector2(0, -24)]), flag_color
	)


func _draw_general(base: Vector2, color: Color) -> void:
	draw_line(base, base + Vector2(0, -24), INK, 2.0)
	var banner := PackedVector2Array([
		base + Vector2(1, -24), base + Vector2(15, -24), base + Vector2(11, -18), base + Vector2(15, -12),
		base + Vector2(1, -12),
	])
	draw_colored_polygon(banner, GOLD)
	draw_polyline(banner, INK, 1.5, true)
	draw_circle(base + Vector2(6, -18), 3.0, color)
