extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var prince: ForestPrince = game.forest.player
	prince.health = 73
	prince.stamina = 42.0
	game.forest._set_essence(125)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	_check(game.mode == &"paused" and paused and game.character_menu.visible, "Escape opens the paused character menu")
	_check(game.menu_stats["Health"].text == "73 / 100" and game.menu_stats["Stamina"].text == "42 / 100" and game.menu_stats["Attack"].text == "0" and game.menu_stats["Defense"].text == "0%", "Menu shows actual player stats")
	_check(game.menu_items["essence"].visible and not game.menu_items["sword"].visible and game.menu_item_description.text.contains("125"), "Inventory only shows collected items and focused essence description")
	_check(game.menu_stance_slots["left"].get_node("Icon").visible and not game.menu_stance_slots["right"].get_node("Icon").visible and not game.menu_stance_slots["up"].get_node("Icon").visible, "Only owned stances occupy their direction slots")
	esc.pressed = false
	Input.parse_input_event(esc)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	Input.parse_input_event(start)
	await process_frame
	_check(game.mode == &"playing" and not paused, "Start closes the menu")
	start.pressed = false
	Input.parse_input_event(start)
	await process_frame
	prince.has_sword = true
	prince.has_amulet = true
	prince.has_blood_amulet = true
	game.forest.has_steel_stance = true
	prince.set_stance(&"steel", false)
	start.pressed = true
	Input.parse_input_event(start)
	await process_frame
	_check(game.mode == &"paused" and game.menu_stance_slots["right"].get_node("Icon").visible and game.menu_stats["Defense"].text == "75%" and game.menu_stats["Attack"].text == "0" and game.menu_stats["Counter"].text == "4", "Start opens refreshed stats and Steel slot")
	_check(game.menu_items["healing"].visible and game.menu_items["blood"].visible, "Collected amulets appear in inventory")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	_check(game.menu_items["healing"].has_focus() and game.menu_item_title.text == "Healing Amulet", "Keyboard direction focuses an item and shows its description")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	_check(game.menu_items["essence"].has_focus() and game.menu_item_description.text.contains("125"), "Controller direction navigates inventory and updates description")
	game.menu_items["blood"].mouse_entered.emit()
	_check(game.menu_items["blood"].has_focus() and game.menu_item_title.text == "Blood Amulet", "Mouse focus shows the selected item description")
	game.menu_resume.pressed.emit()
	_check(game.mode == &"playing" and not paused and not game.character_menu.visible, "Continue resumes gameplay")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All character menu checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
