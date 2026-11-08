extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for enemy in game.forest.enemies + game.forest.bats:
		enemy.set_physics_process(false)
	await _frames(4)
	game.forest.player.position = Vector2(game.forest.FOUNTAIN_X - 60, game.forest.GROUND_Y)
	await _frames(5)
	_check(game.forest.try_rest(), "Rest at fountain")
	_key(KEY_W)
	await _frames(2)
	_check(game.mode == &"merchant" and paused and game.merchant.visible, "Resting W opens merchant and pauses the world")
	_check(game.merchant_buy.disabled and not game.forest.purchase_steel_stance(), "Insufficient Essence prevents purchase")
	game.forest._set_essence(250)
	game._refresh_merchant()
	_check(not game.merchant_buy.disabled, "Purchase becomes available with enough Essence")
	game.merchant_buy.pressed.emit()
	_check(game.forest.has_steel_stance and game.forest.essence == 50 and game.essence_count.text == "50", "Purchase deducts 200 Essence and updates HUD")
	_check(game.merchant_buy.disabled and not game.forest.purchase_steel_stance() and game.forest.essence == 50, "Cannot buy twice")
	game._close_merchant()
	_check(game.mode == &"playing" and not paused and game.forest.player.is_resting, "Leaving merchant returns to rest")
	game.forest.recover_at_fountain()
	_check(game.forest.has_steel_stance and game.forest.essence == 50, "Checkpoint retry retains purchase")
	game.restart_journey()
	_check(not game.forest.has_steel_stance and game.forest.essence == 0, "New journey resets purchase")
	game.forest.player.position = Vector2(game.forest.FOUNTAIN_X - 60, game.forest.GROUND_Y)
	await _frames(5)
	game.forest.try_rest()
	game._open_merchant()
	var icon := game.merchant.get_node("Panel/SteelStanceIcon") as TextureRect
	_check(icon.size == Vector2(112, 112), "Merchant icon stays at the intended small size")
	_key(KEY_G)
	await _frames(2)
	_check(game.forest.player.god_mode and game.essence_count.text == "?" and not game.merchant_buy.disabled, "God mode enables unlimited Essence in the merchant")
	_joy(JOY_BUTTON_DPAD_UP)
	await _frames(2)
	_check(game.merchant_buy.has_focus(), "Controller direction selects purchase")
	_joy(JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	_check(game.merchant_close.has_focus(), "Controller direction selects leave")
	_joy(JOY_BUTTON_DPAD_UP)
	await _frames(2)
	_joy(JOY_BUTTON_X)
	await _frames(2)
	_check(game.forest.has_steel_stance and game.forest.essence == 0 and game.merchant_close.has_focus(), "Controller X buys with unlimited Essence and focuses leave")
	_joy(JOY_BUTTON_A)
	await _frames(2)
	_check(game.mode == &"playing" and not paused, "Controller confirm closes merchant")
	_key(KEY_G)
	await _frames(2)
	_check(not game.forest.player.god_mode and game.essence_count.text == "0", "Turning off god mode restores actual balance")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All merchant checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventJoypadButton.new()
	event.button_index = button
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
