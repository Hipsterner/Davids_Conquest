extends SceneTree

const MapGenerator := preload("res://rules/map_generator.gd")
const GameState := preload("res://rules/game_state.gd")
const Region := preload("res://rules/region.gd")

const GAME_COUNT := 40
const ROUND_LIMIT := 300

var failures := 0


func _initialize() -> void:
	_test_generated_maps()
	_test_income_and_supply()
	_test_plague()
	_test_last_soldier_and_empty_regions()
	_test_revolt()
	_test_combat_capture_and_victory()
	_test_full_games()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _test_generated_maps() -> void:
	for seed_value in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := MapGenerator.generate(rng)
		var regions: Array = map.regions
		var starts: Array = map.starts
		var reached := {0: true}
		var open: Array[int] = [0]
		while not open.is_empty():
			var region: Region = regions[open.pop_back()]
			_check(region.cells.size() >= 4, "seed %d: region %d is tiny" % [seed_value, region.id])
			for next in region.neighbors:
				if not reached.has(next):
					reached[next] = true
					open.append(next)
		_check(reached.size() == MapGenerator.REGION_COUNT, "seed %d: regions not all linked" % seed_value)
		var first_start: Region = regions[starts[0]]
		_check(starts[0] != starts[1], "seed %d: shared start" % seed_value)
		_check(not first_start.neighbors.has(starts[1]), "seed %d: starts touch" % seed_value)


func _line_state(owners: Array, soldiers: Array) -> GameState:
	var regions := []
	for index in owners.size():
		var region := Region.new()
		region.id = index
		if index > 0:
			region.neighbors.append(index - 1)
		if index < owners.size() - 1:
			region.neighbors.append(index + 1)
		regions.append(region)
	var state := GameState.new(regions, [0, owners.size() - 1], RandomNumberGenerator.new())
	for index in owners.size():
		var region: Region = regions[index]
		region.owner = owners[index]
		region.soldiers = soldiers[index]
	state.update_supply()
	return state


func _soldiers(state: GameState) -> Array:
	return state.regions.map(func(region: Region) -> int: return region.soldiers)


func _test_income_and_supply() -> void:
	var state := _line_state([0, 1, 0, GameState.NEUTRAL, 1], [5, 5, 5, 4, 5])
	state.roll_die = func() -> int: return 6
	state.roll_chance = func() -> float: return 0.9
	var supplied := state.regions.map(func(region: Region) -> bool: return region.supplied)
	_check(supplied == [true, false, false, true, true], "supply flags: %s" % [supplied])
	state.end_turn()
	state.end_turn()
	_check(_soldiers(state) == [6, 5, 5, 4, 5], "only the castle earns, barbarians miss their roll: %s" % [_soldiers(state)])
	_check(state.round_number == 2 and state.next_income_round() == 3, "round counter")
	state.roll_chance = func() -> float: return 0.5
	state.end_turn()
	state.end_turn()
	_check(_soldiers(state) == [9, 5, 6, 5, 6], "player one earns and barbarians make their roll: %s" % [_soldiers(state)])
	state.end_turn()
	_check(_soldiers(state) == [9, 6, 6, 5, 9], "player two earns in round three: %s" % [_soldiers(state)])
	for turn in 6:
		state.end_turn()
	_check(state.regions[3].soldiers == GameState.NEUTRAL_CAP, "barbarians stop growing at the cap")


func _test_plague() -> void:
	var state := _line_state([0, GameState.NEUTRAL, 1], [5, 4, 1])
	state.roll_die = func() -> int: return 1
	state.end_turn()
	_check(_soldiers(state) == [3, 2, 1], "plague halves a region but spares a lone soldier: %s" % [_soldiers(state)])
	var struck := state.events.map(func(event: Dictionary) -> int: return event.region)
	_check(struck == [0, 1], "a lone soldier survives the plague unreported: %s" % [struck])
	state.roll_die = func() -> int: return 6
	state.end_turn()
	_check(state.events.is_empty(), "events are cleared by the next world turn")


func _test_last_soldier_and_empty_regions() -> void:
	var state := _line_state([0, GameState.NEUTRAL, 1], [2, 1, 3])
	var rolls := [1, 6, 6, 1, 6, 1]
	var scripted := func() -> int: return rolls.pop_front()
	state.roll_die = scripted
	state.attack_round(0, 1)
	_check(_soldiers(state) == [1, 1, 3] and state.can_attack(0, 1), "the last soldier can attack")
	var capture := state.attack_round(0, 1)
	_check(capture.captured and _soldiers(state) == [0, 1, 3], "a lone victor moves in and leaves home empty")

	state.roll_die = func() -> int: return 6
	state.end_turn()
	state.roll_die = scripted
	state.attack_round(2, 1)
	var walkover := state.attack_round(1, 0)
	_check(walkover.captured and walkover.attack_roll == 0, "an empty region falls without a roll")
	_check(state.winner == 1 and rolls.is_empty(), "the empty castle is lost")

	var chosen := _line_state([0, GameState.NEUTRAL, 1], [5, 1, 1])
	var chosen_rolls := [6, 1]
	chosen.roll_die = func() -> int: return chosen_rolls.pop_front()
	chosen.attack_round(0, 1, 2)
	_check(_soldiers(chosen) == [3, 2, 1], "only the chosen force marches in: %s" % [_soldiers(chosen)])


func _test_revolt() -> void:
	var state := _line_state([0, GameState.NEUTRAL, GameState.NEUTRAL, 1], [2, 1, 1, 5])
	var rolls := [6, 1, 6, 1]
	state.roll_die = func() -> int: return rolls.pop_front()
	state.attack_round(0, 1)
	state.attack_round(1, 2)
	_check(_soldiers(state) == [1, 0, 1, 5], "the last soldier moved on and left the new region empty")
	state.roll_die = func() -> int: return 2
	state.end_turn()
	var owners := state.regions.map(func(region: Region) -> int: return region.owner)
	_check(owners == [0, GameState.NEUTRAL, 0, 1], "only the unmanned new region revolts: %s" % [owners])
	_check(_soldiers(state) == [1, 1, 1, 5] and not state.regions[2].supplied, "rebels hold it and cut the supply line")
	_check(state.events.size() == 1 and state.events[0].kind == "revolt", "the revolt is reported")
	state.roll_die = func() -> int: return 6
	state.end_turn()
	_check(state.regions[2].unrest == 1, "unrest lasts a second round")
	state.end_turn()
	state.end_turn()
	_check(state.regions[2].unrest == 0, "the region is secure after two rounds")


func _test_combat_capture_and_victory() -> void:
	var state := _line_state([0, 1, 0, GameState.NEUTRAL, 1], [5, 2, 5, 1, 1])
	var rolls := [3, 3, 6, 1, 6, 1, 4, 4, 5, 2, 2, 1]
	state.roll_die = func() -> int: return rolls.pop_front()
	state.generals[1] = 1

	state.attack_round(0, 1)
	_check(_soldiers(state) == [5, 2, 5, 1, 1], "tie against a cut-off defender costs nobody")
	state.attack_round(0, 1)
	var capture := state.attack_round(0, 1)
	_check(capture.captured and _soldiers(state) == [1, 4, 5, 1, 1], "capture moves all but one in")
	_check(state.regions[2].supplied, "capture reconnects the cut-off region")
	_check(state.generals == [1, 4], "general follows the conquest, the routed one escapes")

	state.move(1, 2, 99)
	_check(_soldiers(state) == [1, 1, 8, 1, 1], "move leaves one soldier behind")
	_check(not state.can_attack(2, 3), "no attack without the general")
	state.march_general(2)
	_check(state.can_attack(2, 3) and not state.can_march_general(1), "general marches once per turn")
	state.attack_round(2, 3)
	_check(_soldiers(state) == [1, 1, 7, 1, 1], "tie against a supplied defender costs the attacker")
	state.attack_round(2, 3)
	_check(state.winner == GameState.NEUTRAL, "no winner before the castle falls")
	state.attack_round(3, 4)
	_check(state.winner == 0, "taking the enemy castle wins")
	_check(not state.can_attack(3, 4) and not state.can_move(3, 2), "nothing is allowed after victory")

	var rout := _line_state([0, 1, 1, 1], [5, 1, 1, 1])
	var rout_rolls := [6, 1]
	rout.roll_die = func() -> int: return rout_rolls.pop_front()
	rout.generals[1] = 1
	rout.attack_round(0, 1)
	_check(rout.generals == [1, 2], "routed general escapes to the nearest owned region, not the castle: %s" % [rout.generals])

	rout.roll_die = func() -> int: return 6
	for turn in 4:
		rout.end_turn()
	_check(_soldiers(rout).slice(0, 2) == [5, 4], "a conquered region skips its first income: %s" % [_soldiers(rout)])
	for turn in 6:
		rout.end_turn()
	_check(_soldiers(rout).slice(0, 2) == [10, 6], "a recovered region earns again: %s" % [_soldiers(rout)])


func _test_full_games() -> void:
	var finished := 0
	var rounds := 0
	for seed_value in range(1, GAME_COUNT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := MapGenerator.generate(rng)
		var state := GameState.new(map.regions, map.starts, rng)
		while state.winner == GameState.NEUTRAL and state.round_number <= ROUND_LIMIT:
			_play_turn(state)
			state.end_turn()
		_check(_soldiers(state).min() >= 0, "seed %d: a region has negative soldiers" % seed_value)
		if state.winner != GameState.NEUTRAL:
			var fallen: Region = state.regions[state.starts[1 - state.winner]]
			_check(fallen.owner == state.winner, "seed %d: winner does not hold the castle" % seed_value)
			finished += 1
			rounds += state.round_number
	print("bot games finished: %d/%d, average %.1f rounds" % [finished, GAME_COUNT, rounds / maxf(finished, 1)])
	_check(finished == GAME_COUNT, "some bot games never ended")


func _play_turn(state: GameState) -> void:
	var player := state.current_player
	var attacking := true
	while attacking and state.winner == GameState.NEUTRAL:
		attacking = false
		var camp: Region = state.regions[state.generals[player]]
		var target := _weakest_enemy_neighbor(state, camp)
		if target != -1 and camp.soldiers - 1 > state.regions[target].soldiers * 1.5:
			while state.can_attack(camp.id, target):
				state.attack_round(camp.id, target)
			attacking = true
	if state.winner != GameState.NEUTRAL:
		return
	var enemy_ids := []
	for region: Region in state.regions:
		if region.owner != player:
			enemy_ids.append(region.id)
	var to_front := _distances(state, enemy_ids, false)
	if to_front[state.generals[player]] > 1:
		state.march_general(_closer(state.regions[state.generals[player]], to_front))
	var to_general := _distances(state, [state.generals[player]], true)
	for region: Region in state.regions:
		if region.owner == player and to_general.get(region.id, 0) > 0:
			state.move(region.id, _closer(region, to_general), region.soldiers - 1)


func _weakest_enemy_neighbor(state: GameState, region: Region) -> int:
	var weakest := -1
	for next in region.neighbors:
		var other: Region = state.regions[next]
		if other.owner != region.owner and (weakest == -1 or other.soldiers < state.regions[weakest].soldiers):
			weakest = next
	return weakest


func _closer(region: Region, distances: Dictionary) -> int:
	for next in region.neighbors:
		if distances.get(next, INF) < distances[region.id]:
			return next
	return region.id


func _distances(state: GameState, sources: Array, own_only: bool) -> Dictionary:
	var distances := {}
	var open := sources.duplicate()
	for id in sources:
		distances[id] = 0
	while not open.is_empty():
		var region: Region = state.regions[open.pop_front()]
		for next in region.neighbors:
			if distances.has(next) or (own_only and state.regions[next].owner != state.current_player):
				continue
			distances[next] = distances[region.id] + 1
			open.append(next)
	return distances
