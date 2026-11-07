extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/extended_forest_test.gd
## Add -- --capture without --headless to inspect the new forest.

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
	_check(game.forest.enemies.size() == 6 and game.forest.bats.size() == 6, "The extended forest has four additional shades and three additional bats")
	prince.position = Vector2(3600, 586)
	prince.velocity = Vector2.ZERO
	await _frames(8)
	_check(game.mode == &"playing" and not game.forest.completed, "The former ending no longer finishes the stage")
	game.forest.camera.position = Vector2(4170, 360)
	game.forest.camera.reset_smoothing()
	await _capture("extended-forest")
	# Start on each staircase and climb through its actual collision platforms.
	for start_index in [0, 5, 10]:
		var start: StaticBody2D = game.forest.beyond_platforms[start_index]
		prince.position = start.position + Vector2(0, -1)
		prince.velocity = Vector2.ZERO
		await _frames(4)
		_check(prince.is_on_floor(), "The staircase at x=%s supports the prince" % start.position.x)
		for offset in [1, 2]:
			Input.action_press("move_right")
			Input.action_press("jump")
			await _frames(30)
			Input.action_release("move_right")
			await _frames(30)
			Input.action_release("jump")
			await _frames(2)
			var target: StaticBody2D = game.forest.beyond_platforms[start_index + offset]
			_check(prince.is_on_floor() and absf(prince.position.y - target.position.y) < 3.0 and absf(prince.position.x - target.position.x) < 75.0, "Normal jump reaches the branch at %s" % target.position)
	var later_shade: CharacterBody2D = game.forest.enemies[2]
	var later_bat: CharacterBody2D = game.forest.bats[3]
	later_shade.take_damage(4, prince.position)
	later_bat.take_damage(2, prince.position)
	_check(later_shade.health == 0 and later_bat.health == 0, "New enemies can be defeated")
	game.restart_journey()
	await _frames(3)
	_check(later_shade.health == 4 and later_bat.health == 2 and later_shade.position == later_shade.home and later_bat.position == later_bat.home, "Restart restores new enemies to their homes")
	prince.position = Vector2(6950, 586)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	_check(game.mode == &"complete" and paused, "The far exit beyond the fountain completes the stage")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All extended forest checks passed.")
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

func _capture(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
