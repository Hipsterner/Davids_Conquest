extends Node2D

const MapGenerator := preload("res://rules/map_generator.gd")
const GameState := preload("res://rules/game_state.gd")
const Region := preload("res://rules/region.gd")
const MapView := preload("res://map_view.gd")
const Scenery := preload("res://scenery.gd")

const PLAYER_NAMES: Array[String] = ["Crimson Kingdom", "Azure Kingdom"]
const INK := Color("3a2a1a")
const PARCHMENT := Color("ead9b0")
const BUTTON_COLOR := Color("6b4a2b")
const ATTACK_COLOR := Color("a3302a")
const PLAGUE_COLOR := Color("4d7a14")
const INCOME_CHIP := Color("cdb98a")
const CASTLE_CHIP := Color("ddd6c4")
const GENERAL_CHIP := Color("f2c84b")
const CUT_OFF_CHIP := Color("8d867c")
const UNREST_CHIP := Color("ff9d2e")
const SCREEN := Vector2(1280, 800)
const SIDE_WIDTH := 200.0
const MAP_LEFT := SIDE_WIDTH
const MAP_RIGHT := SCREEN.x - SIDE_WIDTH
const TUMBLE_TIME := 0.7
const QUICK_TUMBLE_TIME := 0.3
const HOLD_TIME := 0.3
const TUMBLE_STEP := 0.06
const TOAST_TIME := 1.8
const ANNOUNCE_TIME := 2.2
const GOOD_NEWS := Color("c4f5a6")
const BAD_NEWS := Color("ffa598")
const CARD_DWELL := 0.12
const TIPS := {
	"soldiers": "Soldiers stationed here.\nEach one can attack or defend.",
	"income": "Recruits arriving here in the next recruit round.",
	"barbarians": "Each round this region has this chance\nof gaining a soldier, up to 5.",
	"castle": "Lose your castle and you lose the war.\nIt gains 1 soldier every round.",
	"general": "Only the general's region can attack.\nThe general moves one region per turn.",
	"unsecure": "Newly conquered. For two rounds it may revolt\nif left with no soldiers. One soldier keeps it safe.",
	"cut_off": "No link back to the castle:\nfewer recruits, and ties no longer favour it.",
	"plague": "The plague killed half the soldiers here.",
	"revolt": "This region rose up and went back to the barbarians.",
	"recruits": "New soldiers arrive every third round,\nwhen all three dots are filled.",
}
const NO_SIDE := -1
const ATTACKER := 0
const DEFENDER := 1

var rng := RandomNumberGenerator.new()
var state: GameState
var selected := -1
var hovered := -1
var card_region := -1
var hover_serial := 0
var pointer_on_panel := false
var battle_target := -1
var battle_owners: Array[int] = [0, 0]
var rolling := false
var auto_rolling := false
var pace := 1.0

var view: MapView
var side_columns: Array[VBoxContainer] = []
var side_banners: Array[PanelContainer] = []
var region_counts: Array[Label] = []
var soldier_counts: Array[Label] = []
var turn_box: VBoxContainer
var action_layer: Control
var action_signature := ""
var round_label: Label
var region_name: Label
var chips: HFlowContainer
var result_label: Label
var battle_buttons: VBoxContainer
var battle_force := 0
var force_label: Label
var force_less: Button
var force_more: Button
var roll_button: Button
var roll_all_button: Button
var retreat_button: Button
var general_button: Button
var end_turn_button: Button
var new_island_button: Button
var victory_label: Label
var hint_label: Label
var toast_label: Label
var toast_tween: Tween
var announce_box: PanelContainer
var headline_label: Label
var summary_label: Label
var announce_tween: Tween


func _ready() -> void:
	rng.randomize()
	_fit_window()
	view = MapView.new()
	view.region_clicked.connect(_on_region_clicked)
	view.region_hovered.connect(_on_region_hovered)
	add_child(view)
	_build_panel()
	new_game()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pointer_x: float = make_input_local(event).position.x
		pointer_on_panel = pointer_x < MAP_LEFT or pointer_x >= MAP_RIGHT


func _fit_window() -> void:
	var window := get_window()
	var room := Vector2(DisplayServer.screen_get_usable_rect(window.current_screen).size) * 0.9
	var factor := minf(DisplayServer.screen_get_scale(window.current_screen), minf(room.x / SCREEN.x, room.y / SCREEN.y))
	window.size = Vector2i(SCREEN * factor)
	window.move_to_center()


func new_game() -> void:
	var map := MapGenerator.generate(rng)
	state = GameState.new(map.regions, map.starts, rng)
	view.show_map(state, map.cells, Scenery.generate(map.cells, rng))
	selected = -1
	hovered = -1
	card_region = -1
	_clear_battle()
	_announce_turn()
	_refresh()


func _on_region_clicked(region_id: int, button: int, with_shift: bool) -> void:
	if rolling or state.winner != GameState.NEUTRAL:
		return
	var was_fighting := battle_target != -1
	_clear_battle()
	if region_id == -1:
		selected = -1
	elif button == MOUSE_BUTTON_RIGHT:
		_try_move(region_id, with_shift)
	elif region_id == selected:
		selected = selected if was_fighting else -1
	elif button == MOUSE_BUTTON_LEFT:
		var region: Region = state.regions[region_id]
		if selected != -1 and state.can_attack(selected, region_id):
			_open_battle(region_id)
		elif selected != -1 and region.owner == state.current_player and region.neighbors.has(selected):
			_try_move(region_id, with_shift)
		elif region.owner == state.current_player:
			selected = region_id
		else:
			_explain_blocked_attack(region_id)
	if selected != -1:
		card_region = selected
	_refresh()


func _try_move(target: int, with_shift: bool) -> void:
	if selected == -1:
		_toast("Select one of your regions first", -1, target)
		return
	var source: Region = state.regions[selected]
	var destination: Region = state.regions[target]
	if state.can_move(selected, target):
		state.move(selected, target, source.soldiers - 1 if with_shift else 1)
	elif destination.owner != source.owner:
		_toast("Soldiers only move to your own regions", -1, target)
	elif not source.neighbors.has(target):
		_toast("Too far: move to a neighbouring region", -1, target)
	elif target != selected:
		_toast("One soldier must stay behind", selected, target)


func _explain_blocked_attack(target: int) -> void:
	var camp: Region = state.regions[state.generals[state.current_player]]
	if selected != camp.id:
		_toast("Select your general's region first", camp.id, target)
	elif not camp.neighbors.has(target):
		_toast("Too far: attack a neighbouring region", -1, target)
	else:
		_toast("Not enough soldiers to attack", camp.id, target)


func _toast(text: String, hint_region: int, at_region: int) -> void:
	if toast_tween != null:
		toast_tween.kill()
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	_place(toast_label, view.badge_position(at_region) + Vector2(0, -44))
	view.hint_region = hint_region
	toast_tween = create_tween()
	toast_tween.tween_interval(TOAST_TIME)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	toast_tween.tween_callback(_end_toast)


func _end_toast() -> void:
	toast_label.visible = false
	view.hint_region = -1
	view.queue_redraw()


func _on_region_hovered(region_id: int) -> void:
	hovered = region_id
	hover_serial += 1
	var serial := hover_serial
	await get_tree().create_timer(CARD_DWELL).timeout
	if serial == hover_serial and not pointer_on_panel:
		card_region = hovered if hovered != -1 else selected
		_refresh()


func _open_battle(target: int) -> void:
	var attacker: Region = state.regions[selected]
	var defender: Region = state.regions[target]
	battle_target = target
	battle_owners = [attacker.owner, defender.owner]
	battle_force = state.default_force(selected)
	view.show_dice(target, 0, 0, _owner_color(attacker.owner), _owner_color(defender.owner), NO_SIDE)
	_show_result("", PARCHMENT, target)
	if defender.soldiers == 0:
		_show_round(state.attack_round(selected, target, battle_force))


func _clear_battle() -> void:
	battle_target = -1
	view.hit_region = -1
	view.hide_dice()
	_show_result("", PARCHMENT, -1)


func _roll(until_over: bool) -> void:
	if rolling or battle_target == -1:
		return
	rolling = true
	auto_rolling = until_over
	_refresh()
	await _tumble(QUICK_TUMBLE_TIME if until_over else TUMBLE_TIME)
	_show_round(state.attack_round(selected, battle_target, battle_force))
	while auto_rolling and battle_target != -1:
		await get_tree().create_timer(HOLD_TIME * pace).timeout
		if auto_rolling:
			await _tumble(QUICK_TUMBLE_TIME)
			_show_round(state.attack_round(selected, battle_target, battle_force))
	rolling = false
	auto_rolling = false
	_refresh()


func _toggle_auto_roll() -> void:
	if auto_rolling:
		auto_rolling = false
		_refresh()
	else:
		_roll(true)


func _tumble(duration: float) -> void:
	var elapsed := 0.0
	view.burning = true
	view.hit_region = -1
	while elapsed < duration * pace:
		view.tumble_dice()
		await get_tree().create_timer(TUMBLE_STEP).timeout
		elapsed += TUMBLE_STEP
	view.burning = false


func _show_round(result: Dictionary) -> void:
	var attacker: Region = state.regions[selected]
	var defender: Region = state.regions[battle_target]
	var roll_winner := NO_SIDE
	if result.defender_lost > 0:
		roll_winner = ATTACKER
		view.hit_region = defender.id
	elif result.attacker_lost > 0:
		roll_winner = DEFENDER
		view.hit_region = attacker.id
		battle_force -= 1
	view.show_dice(
		defender.id, result.attack_roll, result.defense_roll, _owner_color(battle_owners[ATTACKER]),
		_owner_color(battle_owners[DEFENDER]), roll_winner
	)
	if result.captured:
		_show_result("Victory", GOOD_NEWS, defender.id)
		view.hit_region = -1
		selected = battle_target
		card_region = selected
		battle_target = -1
	else:
		if battle_force == 0:
			_show_result("Repelled", BAD_NEWS, defender.id)
			battle_target = -1
		elif result.attack_roll != result.defense_roll:
			_show_result("", PARCHMENT, defender.id)
		elif roll_winner == DEFENDER:
			_show_result("Tie: defender wins", BAD_NEWS, defender.id)
		else:
			_show_result("Tie: no losses", PARCHMENT, defender.id)
	_refresh()


func _change_force(amount: int) -> void:
	var attacker: Region = state.regions[selected]
	battle_force = clampi(battle_force + amount, 1, attacker.soldiers)
	_refresh()


func _retreat() -> void:
	_show_result("Retreat", PARCHMENT, battle_target)
	battle_target = -1
	_refresh()


func _show_result(text: String, color: Color, region_id: int) -> void:
	var plate := _box(Color("241a10", 0.94), 8, 6)
	plate.border_color = color
	plate.content_margin_left = 14
	plate.content_margin_right = 14
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	result_label.add_theme_stylebox_override("normal", plate)
	result_label.visible = text != ""
	if result_label.visible:
		_place(result_label, view.dice_anchor(region_id) + Vector2(0, -46))


func _place(control: Control, center: Vector2) -> void:
	control.reset_size()
	var extent := control.size
	control.position = Vector2(
		clampf(center.x - extent.x / 2, MAP_LEFT + 8, MAP_RIGHT - 8 - extent.x),
		clampf(center.y - extent.y / 2, MapView.AREA.position.y, SCREEN.y - 8 - extent.y)
	)


func _march_general() -> void:
	state.march_general(selected)
	_refresh()


func _end_turn() -> void:
	state.end_turn()
	selected = -1
	card_region = -1
	_clear_battle()
	_announce_turn()
	_refresh()


func _announce_turn() -> void:
	var plague := 0
	var revolts := 0
	var parts: Array[String] = []
	for event in state.events:
		if event.kind == "plague":
			plague += event.lost
		else:
			revolts += 1
	if plague > 0:
		parts.append("Plague −%d" % plague)
	if revolts > 0:
		parts.append("Revolt" if revolts == 1 else "%d revolts" % revolts)
	if state.is_income_round():
		parts.append("Recruits arrived")
	var player := state.current_player
	_announce("%s's turn" % PLAYER_NAMES[player], " · ".join(parts), MapView.PLAYER_COLORS[player].lightened(0.55))


func _announce(headline: String, summary: String, color: Color) -> void:
	if announce_tween != null:
		announce_tween.kill()
	var plate := _box(Color("241a10", 0.94), 10, 9)
	plate.border_color = color
	plate.content_margin_left = 24
	plate.content_margin_right = 24
	announce_box.add_theme_stylebox_override("panel", plate)
	headline_label.text = headline
	headline_label.add_theme_color_override("font_color", color)
	summary_label.text = summary
	summary_label.visible = summary != ""
	announce_box.modulate.a = 1.0
	announce_box.visible = true
	announce_tween = create_tween()
	announce_tween.tween_interval(ANNOUNCE_TIME)
	announce_tween.tween_property(announce_box, "modulate:a", 0.0, 0.5)
	announce_tween.tween_callback(announce_box.hide)


func _refresh() -> void:
	var fighting := battle_target != -1
	var over := state.winner != GameState.NEUTRAL
	var filled := state.round_number % GameState.INCOME_ROUNDS
	round_label.text = "Round %d    Recruits %s" % [
		state.round_number,
		"●●●" if filled == 0 else "●".repeat(filled) + "○".repeat(GameState.INCOME_ROUNDS - filled),
	]
	_refresh_sides(over)
	_refresh_region_card(card_region)
	battle_buttons.visible = fighting
	if fighting:
		var attacker: Region = state.regions[selected]
		force_label.text = "Attack with %d of %d" % [battle_force, attacker.soldiers]
		force_less.disabled = rolling or battle_force <= 1
		force_more.disabled = rolling or battle_force >= attacker.soldiers
		_place(battle_buttons, view.badge_position(battle_target) + Vector2(0, 60))
	roll_button.disabled = rolling
	roll_all_button.disabled = rolling and not auto_rolling
	roll_all_button.text = "Stop" if auto_rolling else "Auto-roll"
	retreat_button.disabled = rolling
	general_button.visible = not fighting and selected != -1 and state.can_march_general(selected)
	if general_button.visible:
		_place(general_button, view.badge_position(selected) + Vector2(0, 46))
	end_turn_button.disabled = fighting or rolling or over
	new_island_button.disabled = rolling
	victory_label.visible = over
	if over:
		victory_label.text = "%s wins!" % PLAYER_NAMES[state.winner]
	hint_label.text = _hint()
	_refresh_actions(fighting or rolling or over)
	view.selected = selected
	view.battle_target = battle_target
	view.queue_redraw()


func _refresh_actions(busy: bool) -> void:
	var targets: Array[int] = []
	var owners: Array[int] = []
	if selected != -1 and not busy:
		var source: Region = state.regions[selected]
		var leads := state.generals[state.current_player] == selected
		for next in source.neighbors:
			var region: Region = state.regions[next]
			if leads or region.owner == source.owner:
				targets.append(next)
				owners.append(region.owner)
	var signature := "%d %s %s" % [selected, targets, owners]
	if signature == action_signature:
		return
	action_signature = signature
	_clear_chips(action_layer)
	for target in targets:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		action_layer.add_child(row)
		if state.regions[target].owner == state.current_player:
			_add_action(row, "Move 1", target, false, BUTTON_COLOR)
			_add_action(row, "All", target, true, BUTTON_COLOR)
		else:
			_add_action(row, "Attack", target, false, ATTACK_COLOR)
		_place(row, view.badge_position(target) + Vector2(0, 31))


func _add_action(parent: Control, text: String, target: int, with_shift: bool, color: Color) -> void:
	var button := _add_button(parent, text, _on_region_clicked.bind(target, MOUSE_BUTTON_LEFT, with_shift))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _box(color, 6, 4))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.18), 6, 4))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), 6, 4))


func _hint() -> String:
	if state.winner != GameState.NEUTRAL:
		return ""
	if battle_target != -1:
		return "Roll, or click another region"
	if selected == -1:
		return "Click one of your regions"
	if state.generals[state.current_player] == selected:
		return "Use Move or Attack on a neighbouring region"
	return "Use Move on a neighbouring region. Only the general's region can attack"


func _refresh_sides(over: bool) -> void:
	for player in GameState.PLAYER_COUNT:
		var active := player == state.current_player and not over
		var regions := 0
		var soldiers := 0
		for region: Region in state.regions:
			if region.owner == player:
				regions += 1
				soldiers += region.soldiers
		region_counts[player].text = str(regions)
		soldier_counts[player].text = str(soldiers)
		var plate := _box(MapView.PLAYER_COLORS[player].darkened(0.1), 6, 8)
		plate.border_color = MapView.GOLD if active else INK
		plate.set_border_width_all(4 if active else 2)
		side_banners[player].add_theme_stylebox_override("panel", plate)
		side_columns[player].modulate.a = 1.0 if active or over else 0.5
	var column := side_columns[state.current_player]
	if turn_box.get_parent() != column:
		turn_box.reparent(column)


func _refresh_region_card(region_id: int) -> void:
	_clear_chips(chips)
	region_name.text = ""
	if region_id == -1:
		return
	var region: Region = state.regions[region_id]
	var income := GameState.NEUTRAL_INCOME
	region_name.text = region.name
	_add_chip(chips, "1 soldier" if region.soldiers == 1 else "%d soldiers" % region.soldiers, TIPS.soldiers, _owner_color(region.owner).darkened(0.2))
	if region.owner != GameState.NEUTRAL:
		income = GameState.SUPPLIED_INCOME if region.supplied else GameState.CUT_OFF_INCOME
		if region.recovering > 0:
			income = 0
	if region.owner == GameState.NEUTRAL:
		_add_chip(chips, "%d%%" % roundi(GameState.NEUTRAL_GROWTH_CHANCE * 100), TIPS.barbarians, INCOME_CHIP, INK)
	else:
		_add_chip(chips, "+%d" % income, TIPS.income, INCOME_CHIP, INK)
	if state.starts.has(region_id):
		_add_chip(chips, "Castle +%d" % GameState.CASTLE_INCOME, TIPS.castle, CASTLE_CHIP, INK)
	if region.owner != GameState.NEUTRAL and state.generals[region.owner] == region_id:
		_add_chip(chips, "General", TIPS.general, GENERAL_CHIP, INK)
	if region.owner != GameState.NEUTRAL and region.unrest > 0:
		_add_chip(chips, "Unsecure", TIPS.unsecure, UNREST_CHIP, INK)
	if not region.supplied:
		_add_chip(chips, "Cut off", TIPS.cut_off, CUT_OFF_CHIP)
	for event in state.events:
		if event.region == region_id and event.kind == "plague":
			_add_chip(chips, "Plague −%d" % event.lost, TIPS.plague, PLAGUE_COLOR)
		elif event.region == region_id:
			_add_chip(chips, "Revolt", TIPS.revolt, UNREST_CHIP, INK)


func _owner_color(owner_id: int) -> Color:
	if owner_id == GameState.NEUTRAL:
		return MapView.BARBARIAN_COLOR
	return MapView.PLAYER_COLORS[owner_id]


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui_theme := _make_theme()
	for player in GameState.PLAYER_COUNT:
		var panel := PanelContainer.new()
		panel.theme = ui_theme
		panel.position = Vector2(0 if player == 0 else MAP_RIGHT, 0)
		panel.size = Vector2(SIDE_WIDTH, SCREEN.y)
		layer.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		var banner := PanelContainer.new()
		column.add_child(banner)
		_add_label(banner, 18, Color.WHITE).text = PLAYER_NAMES[player]
		region_counts.append(_add_stat(column, "Regions"))
		soldier_counts.append(_add_stat(column, "Soldiers"))
		side_columns.append(column)
		side_banners.append(banner)

	turn_box = VBoxContainer.new()
	turn_box.add_theme_constant_override("separation", 10)
	turn_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_columns[0].add_child(turn_box)
	turn_box.add_child(HSeparator.new())
	region_name = _add_label(turn_box, 17, INK)
	region_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chips = HFlowContainer.new()
	turn_box.add_child(chips)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	turn_box.add_child(spacer)
	hint_label = _add_label(turn_box, 15, INK)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.x = SIDE_WIDTH - 32
	end_turn_button = _add_button(turn_box, "End turn", _end_turn)

	victory_label = Label.new()
	victory_label.theme = ui_theme
	victory_label.position = Vector2(MAP_LEFT, 330)
	victory_label.size = Vector2(MAP_RIGHT - MAP_LEFT, 100)
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.add_theme_font_size_override("font_size", 56)
	victory_label.add_theme_color_override("font_color", PARCHMENT)
	victory_label.add_theme_color_override("font_outline_color", INK)
	victory_label.add_theme_constant_override("outline_size", 14)
	victory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(victory_label)

	var announce_row := CenterContainer.new()
	announce_row.theme = ui_theme
	announce_row.position = Vector2(MAP_LEFT, 8)
	announce_row.size = Vector2(MAP_RIGHT - MAP_LEFT, MapView.AREA.position.y - 8)
	announce_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(announce_row)
	announce_box = PanelContainer.new()
	announce_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announce_box.visible = false
	announce_row.add_child(announce_box)
	var announce_line := HBoxContainer.new()
	announce_line.add_theme_constant_override("separation", 22)
	announce_box.add_child(announce_line)
	headline_label = _add_label(announce_line, 30, PARCHMENT)
	summary_label = _add_label(announce_line, 20, PARCHMENT)

	var map_ui := Control.new()
	map_ui.theme = ui_theme
	map_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(map_ui)
	action_layer = Control.new()
	action_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.add_child(action_layer)
	battle_buttons = VBoxContainer.new()
	battle_buttons.add_theme_constant_override("separation", 3)
	map_ui.add_child(battle_buttons)
	var force_row := HBoxContainer.new()
	force_row.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_buttons.add_child(force_row)
	force_less = _add_button(force_row, "−", _change_force.bind(-1))
	force_label = _add_label(force_row, 15, PARCHMENT)
	force_label.add_theme_stylebox_override("normal", _box(Color("241a10", 0.94), 6, 5))
	force_more = _add_button(force_row, "+", _change_force.bind(1))
	var roll_row := HBoxContainer.new()
	battle_buttons.add_child(roll_row)
	roll_button = _add_button(roll_row, "Roll once", _roll.bind(false))
	roll_button.tooltip_text = "One round of dice"
	roll_all_button = _add_button(roll_row, "Auto-roll", _toggle_auto_roll)
	roll_all_button.tooltip_text = "Keep rolling until the battle is decided"
	retreat_button = _add_button(roll_row, "Retreat", _retreat)
	for button: Button in [force_less, force_more]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.x = 30
	general_button = _add_button(map_ui, "Move general here", _march_general)
	for button: Button in [roll_button, roll_all_button, retreat_button, general_button, force_less, force_more]:
		button.add_theme_font_size_override("font_size", 14)
	result_label = _add_label(map_ui, 20, PARCHMENT)
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label.visible = false
	toast_label = _add_label(map_ui, 16, PARCHMENT)
	toast_label.add_theme_stylebox_override("normal", _box(Color(INK, 0.92), 8, 8))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	round_label = _add_label(map_ui, 15, PARCHMENT)
	round_label.add_theme_stylebox_override("normal", _box(Color("241a10", 0.8), 8, 6))
	round_label.tooltip_text = TIPS.recruits
	round_label.mouse_filter = Control.MOUSE_FILTER_STOP
	round_label.position = Vector2(MAP_LEFT + 12, SCREEN.y - 44)
	new_island_button = _add_button(map_ui, "New island", new_game)
	new_island_button.add_theme_font_size_override("font_size", 14)
	new_island_button.position = Vector2(MAP_RIGHT - 112, SCREEN.y - 48)


func _add_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_stat(parent: Control, caption: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _add_label(row, 15, Color(INK, 0.8))
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add_label(row, 28, INK)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_chip(parent: Control, text: String, tooltip: String, background: Color, foreground := Color.WHITE) -> void:
	var chip := _add_label(parent, 14, foreground)
	var box := _box(background, 10, 3)
	box.set_border_width_all(1)
	box.content_margin_left = 9
	box.content_margin_right = 9
	chip.text = text
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.add_theme_stylebox_override("normal", box)


func _clear_chips(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino", "Georgia", "Times New Roman"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_stylebox("panel", "PanelContainer", _box(PARCHMENT, 0, 14))
	theme.set_stylebox("normal", "Button", _box(BUTTON_COLOR, 6, 8))
	theme.set_stylebox("hover", "Button", _box(BUTTON_COLOR.lightened(0.15), 6, 8))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_COLOR.darkened(0.2), 6, 8))
	theme.set_stylebox("disabled", "Button", _box(Color(BUTTON_COLOR, 0.3), 6, 8))
	theme.set_stylebox("panel", "TooltipPanel", _box(Color("2b2118"), 6, 8))
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", PARCHMENT)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.5))
	return theme


func _box(color: Color, radius: int, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
