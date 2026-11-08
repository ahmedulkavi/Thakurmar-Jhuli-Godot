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

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
