extends RefCounted

const Region := preload("res://rules/region.gd")

const NEUTRAL := -1
const PLAYER_COUNT := 2
const SUPPLIED_INCOME := 2
const CUT_OFF_INCOME := 1
const NEUTRAL_INCOME := 1
const NEUTRAL_GROWTH_CHANCE := 0.75
const CASTLE_INCOME := 1
const INCOME_ROUNDS := 3
const NEUTRAL_CAP := 5
const RECOVERY_TURNS := 1
const UNREST_ROUNDS := 2
const REVOLT_MAX_ROLL := 2
const START_SOLDIERS := 2
const NEUTRAL_START_SOLDIERS := 1
const DIE_SIDES := 6

var regions: Array = []
var starts: Array = []
var current_player := 0
var round_number := 1
var winner := NEUTRAL
var generals: Array[int] = []
var general_marched := false
var events: Array[Dictionary] = []
var roll_die: Callable
var roll_chance: Callable


func _init(map_regions: Array, map_starts: Array, rng: RandomNumberGenerator) -> void:
	regions = map_regions
	starts = map_starts
	roll_die = func() -> int: return rng.randi_range(1, DIE_SIDES)
	roll_chance = func() -> float: return rng.randf()
	for region: Region in regions:
		region.owner = NEUTRAL
		region.soldiers = NEUTRAL_START_SOLDIERS
	for player in PLAYER_COUNT:
		var start: Region = regions[starts[player]]
		start.owner = player
		start.soldiers = START_SOLDIERS
		generals.append(start.id)
	update_supply()


func end_turn() -> void:
	if winner != NEUTRAL:
		return
	_run_world_turn()
	current_player = (current_player + 1) % PLAYER_COUNT
	general_marched = false
	for region: Region in regions:
		if region.owner == current_player and region.unrest > 0:
			region.unrest -= 1
	if current_player == 0:
		round_number += 1
		_grow_neutrals()
	if round_number > 1:
		var castle: Region = regions[starts[current_player]]
		castle.soldiers += CASTLE_INCOME
	if is_income_round():
		_collect_income()


func is_income_round() -> bool:
	return round_number % INCOME_ROUNDS == 0


func next_income_round() -> int:
	return round_number + INCOME_ROUNDS - round_number % INCOME_ROUNDS


func has_defender_bonus(region_id: int) -> bool:
	var region: Region = regions[region_id]
	return region.owner == NEUTRAL or region.supplied


func can_attack(from_id: int, to_id: int) -> bool:
	var from: Region = regions[from_id]
	var to: Region = regions[to_id]
	return (
		winner == NEUTRAL
		and from.owner == current_player
		and generals[current_player] == from_id
		and to.owner != current_player
		and from.soldiers > 0
		and from.neighbors.has(to_id)
	)


func default_force(from_id: int) -> int:
	var from: Region = regions[from_id]
	return maxi(from.soldiers - 1, 1)


func attack_round(from_id: int, to_id: int, force := 0) -> Dictionary:
	var from: Region = regions[from_id]
	var to: Region = regions[to_id]
	var attack_roll: int = 0 if to.soldiers == 0 else roll_die.call()
	var defense_roll: int = 0 if to.soldiers == 0 else roll_die.call()
	var result := {
		"attack_roll": attack_roll,
		"defense_roll": defense_roll,
		"attacker_lost": 0,
		"defender_lost": 0,
		"captured": false,
	}
	if to.soldiers == 0:
		pass
	elif attack_roll > defense_roll:
		to.soldiers -= 1
		result.defender_lost = 1
	elif attack_roll < defense_roll or has_defender_bonus(to_id):
		from.soldiers -= 1
		result.attacker_lost = 1
	if to.soldiers == 0:
		_capture(from, to, force if force > 0 else default_force(from_id))
		result.captured = true
	return result


func can_move(from_id: int, to_id: int) -> bool:
	var from: Region = regions[from_id]
	var to: Region = regions[to_id]
	return (
		winner == NEUTRAL
		and from.owner == current_player
		and to.owner == current_player
		and from.soldiers > 1
		and from.neighbors.has(to_id)
	)


func move(from_id: int, to_id: int, count: int) -> void:
	if not can_move(from_id, to_id):
		return
	var from: Region = regions[from_id]
	var to: Region = regions[to_id]
	var moved := clampi(count, 0, from.soldiers - 1)
	from.soldiers -= moved
	to.soldiers += moved


func can_march_general(to_id: int) -> bool:
	var camp: Region = regions[generals[current_player]]
	var to: Region = regions[to_id]
	return winner == NEUTRAL and not general_marched and to.owner == current_player and camp.neighbors.has(to_id)


func march_general(to_id: int) -> void:
	if can_march_general(to_id):
		generals[current_player] = to_id
		general_marched = true


func update_supply() -> void:
	var reached := {}
	for player in PLAYER_COUNT:
		var open: Array[int] = []
		var start: Region = regions[starts[player]]
		if start.owner == player:
			reached[start.id] = true
			open.append(start.id)
		while not open.is_empty():
			var region: Region = regions[open.pop_back()]
			for next_id in region.neighbors:
				var next: Region = regions[next_id]
				if next.owner == player and not reached.has(next_id):
					reached[next_id] = true
					open.append(next_id)
	for region: Region in regions:
		region.supplied = region.owner == NEUTRAL or reached.has(region.id)


func _capture(from: Region, to: Region, force: int) -> void:
	var previous_owner := to.owner
	var marching := clampi(force, 1, from.soldiers)
	to.owner = from.owner
	to.soldiers = marching
	to.recovering = RECOVERY_TURNS
	to.unrest = UNREST_ROUNDS
	from.soldiers -= marching
	generals[from.owner] = to.id
	if previous_owner != NEUTRAL:
		if generals[previous_owner] == to.id:
			generals[previous_owner] = _nearest_owned(to.id, previous_owner)
		if to.id == starts[previous_owner]:
			winner = from.owner
	update_supply()


func _nearest_owned(from_id: int, player: int) -> int:
	var seen := {from_id: true}
	var open: Array[int] = [from_id]
	while not open.is_empty():
		var region: Region = regions[open.pop_front()]
		if region.owner == player:
			return region.id
		for next in region.neighbors:
			if not seen.has(next):
				seen[next] = true
				open.append(next)
	return starts[player]


func _run_world_turn() -> void:
	events.clear()
	for region: Region in regions:
		if region.owner != NEUTRAL and region.unrest > 0 and region.soldiers == 0:
			if roll_die.call() <= REVOLT_MAX_ROLL:
				_revolt(region)
		elif roll_die.call() == 1 and roll_die.call() == 1:
			_strike_with_plague(region)


func _revolt(region: Region) -> void:
	var previous_owner := region.owner
	region.owner = NEUTRAL
	region.soldiers = NEUTRAL_START_SOLDIERS
	region.unrest = 0
	region.recovering = 0
	if generals[previous_owner] == region.id:
		generals[previous_owner] = _nearest_owned(region.id, previous_owner)
	events.append({"kind": "revolt", "region": region.id, "owner": previous_owner, "lost": 0})
	update_supply()


func _strike_with_plague(region: Region) -> void:
	var lost := region.soldiers / 2
	if lost == 0:
		return
	region.soldiers -= lost
	events.append({"kind": "plague", "region": region.id, "owner": region.owner, "lost": lost})


func _collect_income() -> void:
	for region: Region in regions:
		if region.owner != current_player:
			continue
		if region.recovering > 0:
			region.recovering -= 1
		else:
			region.soldiers += SUPPLIED_INCOME if region.supplied else CUT_OFF_INCOME


func _grow_neutrals() -> void:
	for region: Region in regions:
		if region.owner == NEUTRAL and region.soldiers < NEUTRAL_CAP and roll_chance.call() < NEUTRAL_GROWTH_CHANCE:
			region.soldiers += NEUTRAL_INCOME
