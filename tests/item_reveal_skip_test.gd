extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/item_reveal_skip_test.gd

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(3)
	var prince: ForestPrince = game.forest.player
	prince.equip_sword(true)
	_check(game.mode == &"item_reveal" and paused, "Sword pickup opens the reveal")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	key.echo = true
	Input.parse_input_event(key)
	await _frames(1)
	_check(game.mode == &"item_reveal", "A repeated held key does not accidentally skip the reveal")
	key.echo = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(game.mode == &"playing" and not paused and not game.amulet_reveal.visible and prince.has_sword and not game.pause_button.disabled, "Restart key skips the sword reveal without restarting")
	key.pressed = false
	Input.parse_input_event(key)

	game._show_item_reveal(&"essence")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await _frames(1)
	enter.pressed = false
	Input.parse_input_event(enter)
	await _frames(2)
	prince.equip_amulet()
	_check(game.mode == &"item_reveal" and prince.has_amulet and game.reveal_art.texture == game.AMULET_TEXTURE, "Amulet pickup restores its own artwork after an Essence reveal")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_START
	button.pressed = true
	Input.parse_input_event(button)
	await _frames(2)
	_check(game.mode == &"playing" and not paused and prince.has_amulet, "Controller pause button skips the amulet reveal without pausing")
	button.pressed = false
	Input.parse_input_event(button)

	game._show_item_reveal(&"sword")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(2)
	_check(game.mode == &"playing" and not paused and not game.amulet_reveal.visible, "Mouse click skips the reveal")
	click.pressed = false
	Input.parse_input_event(click)

	game._show_item_reveal(&"amulet")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(2)
	_check(game.mode == &"playing" and not paused, "Touch skips the reveal")
	# A killed tween must not later dismiss another active reveal.
	game._show_item_reveal(&"amulet")
	await _frames(100)
	_check(game.mode == &"item_reveal" and paused and game.amulet_reveal.visible, "Skipped animations do not interrupt a later reveal")
	await _frames(160)
	_check(game.mode == &"playing" and not paused and not game.amulet_reveal.visible, "A reveal still finishes automatically without input")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All item reveal skip checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)
