extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/fountain_rest_test.gd
## Omit --headless and add -- --capture for a screenshot.

var game: Control
var prince: ForestPrince
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	prince = game.forest.player
	for enemy in game.forest.enemies + game.forest.bats:
		enemy.set_physics_process(false)
	await _frames(4)
	_check(game.forest.fountain.position.x > game.forest.get_node("Banyan").position.x and game.forest.fountain.position.x < game.forest.get_node("Goal").position.x, "Fountain stands beyond the banyan and before the exit")
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _frames(2)
	_check(not prince.is_resting, "Cannot rest away from the fountain")
	prince.equip_sword()
	prince.has_amulet = true
	prince._set_magic(35.0, true)
	prince.health = 28
	prince.health_changed.emit(prince.health, ForestPrince.MAX_HEALTH)
	prince.stamina = 12.0
	var shade: CharacterBody2D = game.forest.enemies[0]
	var bat: CharacterBody2D = game.forest.bats[0]
	shade.take_damage(4, Vector2.ZERO)
	bat.take_damage(2, Vector2.ZERO)
	await _frames(2)
	prince.position = Vector2(game.forest.FOUNTAIN_X - 60.0, game.forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	game.forest.camera.position = Vector2(game.forest.FOUNTAIN_X + 220.0, 360)
	game.forest.camera.reset_smoothing()
	_key(KEY_E, true)
	await _frames(2)
	_check(prince.is_resting and prince.rest_art.visible and not prince.animation.visible, "Interact seats the prince at the fountain")
	_check(prince.health == 100 and game.health_bar.value == 100 and prince.stamina == 100.0, "Rest restores health, stamina and the HUD")
	_check(shade.health == 4 and bat.health == 2 and shade.position == shade.home and bat.position == bat.home, "Rest revives enemies at their starting positions")
	_check(prince.has_sword and prince.has_amulet and prince.magic == 35.0 and game.forest.checkpoint_active, "Rest preserves equipment and magic and activates a checkpoint")
	var seated_at := prince.position
	var initial_pose := prince.rest_art.scale
	var water: Node2D = game.forest.fountain.get_node("FlowingWater")
	var leaves: Node2D = game.forest.get_node("MiddleForest/DistantLeaves")
	var water_time: float = water.elapsed
	var leaves_time: float = leaves.elapsed
	await _frames(100)
	_check(prince.is_resting and prince.position == seated_at and not prince.take_damage(10, Vector2.ZERO), "The prince stays seated and safe until a new button press")
	_check(prince.rest_art.scale != initial_pose and water.elapsed > water_time and leaves.elapsed > leaves_time, "Resting breathes while fountain water and distant leaves animate")
	game.pause_journey()
	var frozen_pose := prince.rest_art.scale
	water_time = water.elapsed
	leaves_time = leaves.elapsed
	await _frames(30)
	_check(prince.rest_art.scale == frozen_pose and water.elapsed == water_time and leaves.elapsed == leaves_time, "Pause freezes the resting pose, water and background leaves")
	game.resume_journey()
	await _capture("fountain-rest")
	_key(KEY_E, false)
	await _frames(2)
	_check(prince.is_resting, "Releasing the interaction key does not end the rest")
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	_check(not prince.is_resting and not prince.rest_art.visible and not paused and prince.health == 100, "Another button stands the prince up and resumes play")
	prince.take_damage(1000, prince.position + Vector2(100, 0))
	_check(game.mode == &"defeated" and paused, "Death still opens the retry screen")
	game.primary.pressed.emit()
	await _frames(4)
	_check(game.mode == &"playing" and not paused and prince.health == 100 and absf(prince.position.x - game.forest.FOUNTAIN_X) < 100.0, "Retry after death returns to the fountain with full health")
	_check(prince.has_sword and prince.has_amulet and prince.magic == 35.0, "Checkpoint retry preserves collected equipment and magic")
	game.restart_journey()
	await _frames(3)
	_check(not game.forest.checkpoint_active and prince.position.x < 171.0 and not prince.has_sword, "Normal restart begins a new journey and clears the checkpoint")
	prince.position = Vector2(game.forest.FOUNTAIN_X - 60.0, game.forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await _frames(2)
	_check(prince.is_resting and prince.rest_art.texture.resource_path.ends_with("prince-resting-unarmed.png"), "Controller shoulder rests with the unarmed pose when the sword was not collected")
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	await _frames(2)
	var face_button := InputEventJoypadButton.new()
	face_button.button_index = JOY_BUTTON_A
	face_button.pressed = true
	Input.parse_input_event(face_button)
	await _frames(2)
	_check(not prince.is_resting and game.mode == &"playing", "Controller face button stands up without starting another action")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All fountain rest checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _capture(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
