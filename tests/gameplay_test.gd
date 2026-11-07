extends SceneTree
## Run with --headless --path . --script res://tests/gameplay_test.gd
## Omit --headless and add -- --capture for screenshots in artifacts/.

var game: Control
var prince: ForestPrince
var failures: Array[String] = []
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	prince = game.forest.player
	await _frames(10)
	_check(prince.is_on_floor(), "Prince settles on the floor")
	_check(is_equal_approx(prince.position.y, 586.0), "Floor aligns with the artwork")
	await _screenshot("forest-start")

	# Send actual key events so incorrect InputMap keycodes cannot pass unnoticed.
	for binding in [[KEY_LEFT, -1.0, "Left arrow"], [KEY_RIGHT, 1.0, "Right arrow"], [KEY_A, -1.0, "A"], [KEY_D, 1.0, "D"]]:
		game.restart_journey()
		await _frames(3)
		var start_x: float = prince.position.x
		_key_state(binding[0], true)
		await _frames(18)
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), binding[1]), binding[2] + " activates the correct movement action")
		_check((prince.position.x - start_x) * binding[1] > 20.0, binding[2] + " moves the prince in the correct direction")
		_key_state(binding[0], false)
		await _frames(12)
		_check(is_zero_approx(prince.velocity.x), binding[2] + " release stops movement")
	for unrelated_key in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
		_key_state(unrelated_key, true)
		_check(is_zero_approx(Input.get_axis("move_left", "move_right")), OS.get_keycode_string(unrelated_key) + " does not trigger horizontal movement")
		_key_state(unrelated_key, false)
	game.restart_journey()
	await _frames(3)

	Input.action_press("move_left")
	await _frames(90)
	Input.action_release("move_left")
	_check(prince.position.x >= 21.9 and prince.position.x <= 23.0, "Left world boundary blocks movement")
	_key(KEY_R)
	await _frames(2)
	_check(absf(prince.position.x - 170.0) < 1.0, "R restarts the journey")
	prince.position = Vector2(600, 586)
	Input.action_press("move_right")
	await _frames(25)
	_check(prince.animation.animation == &"run", "Movement uses the run animation")
	await _frames(65)
	_check(prince.position.x > 816.0 and prince.position.x < 820.0, "Log blocks walking at its visible edge")
	Input.action_release("move_right")

	# Rocks remain solid, but landing on their peak or either side must slide
	# the prince down to the ground rather than leave him on a platform.
	game.restart_journey()
	prince.position = Vector2(1640, 586)
	await _frames(3)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(prince.position.x < 1750.0, "Rocks block walking through from the left")
	game.restart_journey()
	prince.position = Vector2(1980, 586)
	await _frames(3)
	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	_check(prince.position.x > 1870.0, "Rocks block walking through from the right")
	for landing_x in [1775.0, 1818.0, 1845.0]:
		game.restart_journey()
		prince.position = Vector2(landing_x, 420)
		await _frames(150)
		_check(prince.is_on_floor() and absf(prince.position.y - 586.0) < 1.0, "Landing on rocks at x=%s slides down to the ground" % landing_x)
		_check(prince.position.x < 1730.0 or prince.position.x > 1890.0, "Prince cannot remain standing on the rocks at x=%s" % landing_x)
	game.restart_journey()
	prince.position = Vector2(1818, 420)
	for i in range(40):
		await _frames(1)
		if not is_zero_approx(prince.slide_direction):
			break
	_check(not is_zero_approx(prince.slide_direction), "Landing on the rock peak starts a slide")
	Input.action_press("jump")
	Input.action_press("move_left")
	await _frames(8)
	_check(prince.velocity.y >= 0.0, "Rock contact does not grant a grounded jump")
	Input.action_release("jump")
	await _frames(120)
	Input.action_release("move_left")
	_check(prince.position.y > 585.0, "Holding against the slide cannot keep the prince on the rocks")

	# The root is a platform: feet should meet the visible anvil-shaped cap,
	# rather than the old floating box or the over-lowered interior surface.
	for landing_x in [2620.0, 2650.0, 2680.0]:
		game.restart_journey()
		prince.collision_mask = 1
		prince.position = Vector2(landing_x, 380)
		await _frames(90)
		var supported_by_root := false
		for i in range(prince.get_slide_collision_count()):
			if prince.get_slide_collision(i).get_collider() == game.forest.get_node("Root"):
				supported_by_root = true
		_check(prince.is_on_floor() and supported_by_root, "Root's anvil cap supports the prince at x=%s" % landing_x)
		_check(prince.position.y > 493.0 and prince.position.y < 510.0, "Prince's feet align with the root's visible top at x=%s" % landing_x)
		if landing_x == 2650.0:
			await _screenshot("forest-root-landing")
	prince.collision_mask = 9
	game.restart_journey()
	await _frames(3)

	_key(KEY_ESCAPE)
	await _frames(2)
	_check(paused and game.mode == &"paused" and game.overlay.visible, "Esc opens the pause screen")
	var paused_position := prince.position
	Input.action_press("move_right")
	await _frames(20)
	_check(prince.position == paused_position, "Godot pause freezes physics")
	await _screenshot("forest-paused")
	game.primary.pressed.emit()
	await _frames(2)
	_check(not paused and game.mode == &"playing", "Continue button resumes")
	game.restart_journey()
	await _frames(3)

	Input.action_press("jump")
	var high_y: float = prince.position.y
	for i in range(48):
		await _frames(1)
		high_y = minf(high_y, prince.position.y)
	Input.action_release("jump")
	await _frames(12)
	_check(high_y < 450.0 and prince.is_on_floor(), "Held jump reaches full height and lands")
	game.restart_journey()
	await _frames(3)
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	var low_y: float = prince.position.y
	for i in range(48):
		await _frames(1)
		low_y = minf(low_y, prince.position.y)
	_check(low_y > high_y + 40.0, "Releasing jump produces a shorter hop")

	# Press shortly before landing: the buffered jump must launch on contact.
	prince.position = Vector2(700, 470)
	prince.velocity = Vector2(0, 300)
	await _frames(2)
	for i in range(30):
		if prince.position.y > 552.0:
			break
		await _frames(1)
	Input.action_press("jump")
	await _frames(8)
	_check(prince.velocity.y < -400.0, "Jump buffer accepts input just before landing")
	Input.action_release("jump")
	await _frames(50)

	# Walk off a raised platform, then jump in the coyote grace period.
	var log_collision := game.forest.get_node("Log/Collision") as CollisionShape2D
	var log_shape := log_collision.shape as RectangleShape2D
	prince.position = Vector2(970, log_collision.global_position.y - log_shape.size.y / 2.0)
	prince.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("move_right")
	for i in range(30):
		await _frames(1)
		if not prince.is_on_floor():
			break
	Input.action_press("jump")
	await _frames(2)
	_check(prince.velocity.y < -500.0, "Coyote time allows a jump just after leaving a ledge")
	Input.action_release("jump")
	Input.action_release("move_right")

	game.restart_journey()
	await _frames(3)
	# This checks the original traversal geometry; combat is covered separately.
	for enemy in game.forest.enemies + game.forest.bats:
		enemy.set_physics_process(false)
	Input.action_press("move_right")
	var next_obstacle: int = 0
	var cleared: Array[bool] = [false, false, false, false, false, false, false]
	var obstacle_x: Array[float] = [450.0, 910.0, 1810.0, 2650.0, 4200.0, 4780.0, 5530.0]
	var jump_held: int = 0
	var saw_sword_reveal := false
	for i in range(2350):
		await _frames(1)
		if game.mode == &"complete":
			break
		if game.mode == &"item_reveal":
			saw_sword_reveal = true
			continue
		Input.action_press("move_right")
		if jump_held > 0:
			jump_held -= 1
			if jump_held == 0:
				Input.action_release("jump")
		if next_obstacle < obstacle_x.size() and prince.position.x > obstacle_x[next_obstacle] - 150.0 and prince.is_on_floor():
			Input.action_press("jump")
			jump_held = 46
			next_obstacle += 1
		for j in range(obstacle_x.size()):
			if prince.position.x > obstacle_x[j] + 105.0:
				cleared[j] = true
		if i == 320:
			await _screenshot("forest-journey")
	Input.action_release("move_right")
	Input.action_release("jump")
	if game.mode != &"complete":
		print("TRAVERSAL DIAGNOSTICS: mode=%s position=%s velocity=%s obstacle=%s cleared=%s" % [game.mode, prince.position, prince.velocity, next_obstacle, cleared])
	_check(saw_sword_reveal, "Collecting the sword pauses traversal for its item reveal")
	_check(cleared.all(func(value: bool) -> bool: return value), "Prince clears the original and extended forest obstacles using normal jumps")
	_check(game.mode == &"complete" and paused, "Reaching the far exit completes and pauses the game")
	_check(game.heading.text == "Forest path complete", "Completion presents the ending")
	_check(game.forest.camera.position.x > 5900.0, "Camera follows the extended route")
	await _screenshot("forest-complete")
	game.primary.pressed.emit()
	await _frames(3)
	_check(game.mode == &"playing" and not paused and prince.position.x < 171.0, "Walk again button resets the completed game")
	_check(not game.forest.completed and not game.overlay.visible, "Restart clears completion and overlay state")
	game.pause_journey()
	_key(KEY_R)
	await _frames(2)
	_check(not paused and game.mode == &"playing", "R also restarts while paused")
	if failures.is_empty():
		print("PASS: All gameplay checks passed.")
	else:
		for failure in failures:
			push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _key(keycode: Key) -> void:
	_key_state(keycode, true)
	_key_state(keycode, false)

func _key_state(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _screenshot(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
