extends SceneTree

const GameState := preload("res://rules/game_state.gd")
const Region := preload("res://rules/region.gd")

var main: Node
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	await _shot("01_start")
	var state: GameState = main.state
	var camp: Region = state.regions[state.generals[0]]
	var target: Region = state.regions[camp.neighbors[0]]
	_hover(main.view._position_of(camp.center))
	await create_timer(0.3).timeout
	print("card after dwelling on the castle: ", _card())
	_hover(main.view._position_of(target.center))
	_hover(Vector2(1180, 400))
	await create_timer(0.3).timeout
	print("card after crossing another region into the panel: ", _card())
	_click(target.id, MOUSE_BUTTON_LEFT)
	print("toast with nothing selected: '%s', hint is general's region: %s" % [main.toast_label.text, main.view.hint_region == camp.id])
	await _shot("01b_toast")
	_click(camp.id, MOUSE_BUTTON_LEFT)
	for region: Region in state.regions:
		if region.owner != 0 and not camp.neighbors.has(region.id):
			_click(region.id, MOUSE_BUTTON_LEFT)
			break
	print("toast for a far region: '%s', selection kept: %s" % [main.toast_label.text, main.selected == camp.id])
	print("selected card: ", _card())
	await _shot("02_selected")
	_click(target.id, MOUSE_BUTTON_LEFT)
	print("battle target after real click: ", main.battle_target)
	if camp.neighbors.size() > 1:
		_click(camp.neighbors[1], MOUSE_BUTTON_LEFT)
		print("re-chosen target: %s, buttons shown %s" % [main.battle_target == camp.neighbors[1], main.battle_buttons.visible])
		_click(camp.id, MOUSE_BUTTON_LEFT)
		print("clicking own region cancels: target %d, selected is camp %s, dice shown %s" % [main.battle_target, main.selected == camp.id, main.view.dice_region != -1])
		_click(target.id, MOUSE_BUTTON_LEFT)
	main.retreat_button.pressed.emit()
	print("after retreat: target %d, result '%s'" % [main.battle_target, main.result_label.text])

	camp.soldiers = 9
	target.soldiers = 3
	_click(target.id, MOUSE_BUTTON_LEFT)
	var fair_die := state.roll_die
	state.roll_die = func() -> int: return 4
	main.roll_button.pressed.emit()
	await _shot("03_tumbling")
	print("mid-roll: rolling %s, roll/end/new disabled %s" % [main.rolling, [main.roll_button.disabled, main.end_turn_button.disabled, main.new_island_button.disabled]])
	await _settle()
	state.roll_die = fair_die
	print("after a forced tie: '%s', sides %s, hit is attacker %s" % [main.result_label.text, _sides(), main.view.hit_region == camp.id])
	await _shot("04_after_roll")
	if main.battle_target != -1:
		camp.soldiers = 30
		target.soldiers = 20
		main.roll_all_button.pressed.emit()
		await process_frame
		print("auto-rolling: button '%s', disabled %s" % [main.roll_all_button.text, main.roll_all_button.disabled])
		await _shot("04b_auto_rolling")
		main.roll_all_button.pressed.emit()
		await _settle()
		print("stopped: battle open %s, button '%s', sides %s" % [main.battle_target != -1, main.roll_all_button.text, _sides()])
		target.soldiers = 1
		main.roll_all_button.pressed.emit()
		await _settle()
	print("battle over: '%s', sides %s, owner %d, general %s" % [main.result_label.text, _sides(), target.owner, state.generals])
	await _shot("05_battle_over")

	if target.owner == 0:
		print("before moves: ", [camp.soldiers, target.soldiers])
		_click(camp.id, MOUSE_BUTTON_RIGHT)
		_click(camp.id, MOUSE_BUTTON_RIGHT, true)
		print("after right-click and shift right-click: ", [camp.soldiers, target.soldiers])
		main.selected = camp.id
		main._refresh()
		print("general button visible: ", main.general_button.visible)
		main.general_button.pressed.emit()
		print("general after march: %s, button visible: %s" % [state.generals, main.general_button.visible])
		main._refresh_region_card(target.id)
		print("conquered card: ", _card())

	var real_die := state.roll_die
	state.roll_die = func() -> int: return 1
	main._end_turn()
	state.roll_die = real_die
	print("events: %d, banner '%s'" % [state.events.size(), main.summary_label.text])
	main._refresh_region_card(state.events[0].region)
	print("plague card: ", _card())
	await _shot("06_plague")

	main.pace = 0.0
	for turn in 14:
		await _play_turn()
		main._end_turn()
	for region: Region in state.regions:
		var touches_own := region.neighbors.any(func(next: int) -> bool: return state.regions[next].owner == 0)
		if region.owner == GameState.NEUTRAL and not touches_own:
			region.owner = 0
			state.update_supply()
			main._refresh_region_card(region.id)
			print("cut-off card: ", _card())
			break
	_click(state.generals[state.current_player], MOUSE_BUTTON_LEFT)
	await _shot("07_midgame")
	var walk_camp: Region = state.regions[state.generals[state.current_player]]
	for next in walk_camp.neighbors:
		var empty: Region = state.regions[next]
		if empty.owner != walk_camp.owner and not state.starts.has(next):
			empty.soldiers = 0
			walk_camp.soldiers = 1
			_click(next, MOUSE_BUTTON_LEFT)
			print("walkover with one soldier: result '%s', owner changed %s, soldiers %s, rolling %s" % [main.result_label.text, empty.owner == walk_camp.owner, [walk_camp.soldiers, empty.soldiers], main.rolling])
			main._refresh_region_card(next)
			print("new region card: ", _card())
			await _shot("07b_walkover")
			empty.soldiers = 0
			var calm_die := state.roll_die
			state.roll_die = func() -> int: return 2
			main._end_turn()
			state.roll_die = calm_die
			main._refresh_region_card(next)
			print("after revolt: owner %d, banner '%s', card %s" % [empty.owner, main.summary_label.text, _card()])
			await _shot("07c_revolt")
			break
	state.winner = state.current_player
	main._refresh()
	await _shot("08_victory")
	quit()


func _play_turn() -> void:
	var state: GameState = main.state
	for attempt in 4:
		var camp: Region = state.regions[state.generals[state.current_player]]
		for region: Region in state.regions:
			if region.owner == state.current_player and camp.neighbors.has(region.id):
				main.selected = region.id
				main._on_region_clicked(camp.id, MOUSE_BUTTON_RIGHT, true)
		var target := -1
		for next in camp.neighbors:
			var other: Region = state.regions[next]
			if other.owner != camp.owner and state.starts.find(next) == -1:
				if target == -1 or other.soldiers < state.regions[target].soldiers:
					target = next
		if target == -1 or camp.soldiers - 1 <= state.regions[target].soldiers * 1.5:
			return
		main.selected = camp.id
		main._on_region_clicked(target, MOUSE_BUTTON_LEFT, false)
		await main._roll(true)


func _card() -> String:
	return "%s %s" % [main.region_name.text, _texts(main.chips)]


func _sides() -> Array:
	return main.view.dice_rolls


func _texts(container: Control) -> Array:
	return container.get_children().map(func(chip: Label) -> String: return chip.text)


func _click(region_id: int, button: MouseButton, with_shift := false) -> void:
	var region: Region = main.state.regions[region_id]
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.shift_pressed = with_shift
		event.position = root.get_final_transform() * main.view._position_of(region.center)
		event.global_position = event.position
		root.push_input(event)


func _hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	root.push_input(event)


func _settle() -> void:
	while main.rolling:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
