extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var prince: ForestPrince = game.forest.player
	for enemy in game.forest.enemies + game.forest.bats:
		enemy.set_physics_process(false)
	await _frames(5)
	_check(not prince.god_mode and not game.god_mode_indicator.visible, "God mode starts disabled")
	_key(KEY_G)
	await _frames(2)
	_check(prince.god_mode and game.god_mode_indicator.visible, "G enables god mode and indicator")
	_check(not prince.take_damage(1000, Vector2.ZERO) and prince.health == 100, "God mode prevents lethal damage")
	prince.has_sword = true
	prince.position = Vector2(2920, 586)
	var shade: CharacterBody2D = game.forest.enemies[0]
	shade.position = Vector2(3000, 586)
	await _frames(4)
	_check(prince.attack(), "Sword attack starts")
	await _frames(14)
	_check(shade.health == 0, "Sword kills a shade in one hit")
	var bat: CharacterBody2D = game.forest.bats[0]
	bat.position = Vector2(3000, 540)
	await _frames(30)
	_check(prince.attack(), "Second sword attack starts")
	await _frames(14)
	_check(bat.health == 0, "Sword kills a bat in one hit")
	game.restart_journey()
	_check(prince.god_mode and game.god_mode_indicator.visible, "God mode persists through restart")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_BACK
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	_check(not prince.god_mode and not game.god_mode_indicator.visible, "Controller Select disables god mode")
	_check(prince.take_damage(20, Vector2.ZERO) and prince.health == 80, "Normal damage returns when disabled")
	_joy_button(JOY_BUTTON_BACK, false)
	prince.position = Vector2(200, game.forest.GROUND_Y)
	_joy_button(JOY_BUTTON_BACK, true)
	await _frames(2)
	_check(prince.god_mode, "Select alone still toggles god mode")
	_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await _frames(2)
	_check(absf(prince.position.x - (game.forest.boss_arena.FOG_X - 60.0)) < 2.0 and prince.position.y == game.forest.GROUND_Y, "Select then Down teleports before Shakchunni")
	_check(is_equal_approx(game.forest.camera.position.y, 360.0), "Teleport retains ground-level camera framing")
	_check(not prince.god_mode and not game.god_mode_indicator.visible and not game.forest.boss_arena.active, "Teleport preserves god mode and leaves encounter dormant")
	_joy_button(JOY_BUTTON_BACK, false)
	_joy_button(JOY_BUTTON_DPAD_DOWN, false)
	prince.position = Vector2(200, game.forest.GROUND_Y)
	_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	_joy_button(JOY_BUTTON_BACK, true)
	await _frames(2)
	_check(absf(prince.position.x - (game.forest.boss_arena.FOG_X - 60.0)) < 2.0 and not prince.god_mode, "Down then Select teleports without toggling god mode")
	_joy_button(JOY_BUTTON_BACK, false)
	_joy_button(JOY_BUTTON_DPAD_DOWN, false)
	# Either order of the chord selects the second arena when swimming.
	for down_first in [false, true]:
		prince.position = Vector2(11000, 800)
		prince.velocity = Vector2.ZERO
		await _frames(3)
		_check(prince.in_water, "Debug shortcut starts underwater")
		var god_mode_before := prince.god_mode
		if down_first:
			_joy_button(JOY_BUTTON_DPAD_DOWN, true)
			_joy_button(JOY_BUTTON_BACK, true)
		else:
			_joy_button(JOY_BUTTON_BACK, true)
			_joy_button(JOY_BUTTON_DPAD_DOWN, true)
		await _frames(3)
		var rival: CharacterBody2D = game.forest.underwater.boss
		_check(absf(prince.position.x - (rival.ENTRY_X - 60.0)) < 2.0 and is_equal_approx(prince.position.y, prince.HALL_FLOOR_Y), "Underwater shortcut lands before the second boss arena")
		_check(not prince.in_water and not rival.active and prince.god_mode == god_mode_before, "Underwater shortcut restores land movement, preserves god mode and leaves rival dormant")
		_check(is_equal_approx(game.forest.camera.position.y, prince.HALL_FLOOR_Y - 275.0), "Second boss shortcut frames the dry hall")
		_joy_button(JOY_BUTTON_BACK, false)
		_joy_button(JOY_BUTTON_DPAD_DOWN, false)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check(not game.forest.underwater.boss.active, "Walking forward after the shortcut stops at the second fog gate")
	_key(KEY_E)
	await _frames(2)
	_check(game.forest.underwater.boss.active, "Interacting with the fog after the shortcut starts the second boss encounter")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All god mode checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

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

func _joy_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
