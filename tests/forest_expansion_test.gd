extends SceneTree
## Run with --headless --path . --fixed-fps 60 --script res://tests/forest_expansion_test.gd
## Omit --headless and add -- --capture for screenshots.

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
	await _frames(5)
	_check(game.forest.platforms.size() == 5 and game.forest.ladder_guardians.size() == 3, "The original staircase has five branches and three guardian bats")
	_check(game.forest.sword_pickup.position.x < 500.0 and game.forest.get_node("SwordRoot").position.x == game.forest.sword_pickup.position.x, "Sword and anvil are together near the starting point")
	await _capture("forest-expansion-start")
	Input.action_press("move_right")
	await _frames(27)
	Input.action_press("jump")
	await _frames(32)
	Input.action_release("move_right")
	await _frames(35)
	Input.action_release("jump")
	_check(prince.has_sword and game.forest.sword_pickup.collected, "Running and jumping from the start collects the nearby sword")

	# Jump through the first one-way branch, then climb between real platforms.
	game.restart_journey()
	prince.position = Vector2(1980, 586)
	prince.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("jump")
	await _frames(50)
	Input.action_release("jump")
	_check(prince.is_on_floor() and absf(prince.position.y - 510.0) < 3.0, "Jump passes up through the first branch and lands on it")
	await _frames(2)
	for platform_index in [1, 2, 3, 4]:
		Input.action_press("move_right")
		Input.action_press("jump")
		await _frames(30)
		Input.action_release("move_right")
		await _frames(30)
		Input.action_release("jump")
		await _frames(2)
		var platform: StaticBody2D = game.forest.platforms[platform_index]
		if not prince.is_on_floor() or absf(prince.position.y - platform.position.y) >= 3.0 or absf(prince.position.x - platform.position.x) >= 75.0:
			print("PLATFORM DIAGNOSTICS: player=%s velocity=%s target=%s" % [prince.position, prince.velocity, platform.position])
		_check(prince.is_on_floor() and absf(prince.position.y - platform.position.y) < 3.0 and absf(prince.position.x - platform.position.x) < 75.0, "Normal held jump reaches branch %d" % (platform_index + 1))
		if platform_index == 2:
			await _capture("forest-expansion-platforms")

	# Sword collision and damage use the same real hit query as the shades.
	game.restart_journey()
	prince.position = Vector2(1200, 586)
	prince.equip_sword()
	var bat: CharacterBody2D = game.forest.bats[0]
	bat.position = Vector2(1280, 560)
	await _frames(4)
	_check(prince.attack(), "Sword attack starts against a flying bat")
	await _frames(12)
	_check(bat.health == 1 and bat.state == &"hurt", "Sword hit damages and interrupts a bat")
	await _frames(25)
	_check(prince.attack(), "Second sword swing starts after recovery")
	await _frames(12)
	_check(bat.health == 0 and bat.state == &"dead" and bat.collision_layer == 0, "Second sword hit defeats the bat and removes its hitbox")
	bat.set_physics_process(true)
	await _frames(30)
	_check(not bat.visible, "Defeated bat fades away")
	game.restart_journey()
	_check(bat.health == 2 and bat.visible and bat.state == &"patrol", "Restart restores defeated bats")

	# A real bat telegraphs its dive and contacts the player without test damage.
	bat.home = Vector2(1300, 540)
	bat.reset_enemy()
	bat.set_physics_process(true)
	prince.position = Vector2(1200, 586)
	prince.set_physics_process(false)
	await _frames(6)
	_check(bat.state == &"windup" and prince.health == 100, "Bat warns before diving")
	await _capture("forest-expansion-bat")
	var saw_dive := false
	for i in range(100):
		await _frames(1)
		saw_dive = saw_dive or bat.state == &"dive"
		if prince.health < 100:
			break
	_check(saw_dive and prince.health == 85, "Bat dives and deals 15 damage on contact")
	game.pause_journey()
	var frozen_position := bat.position
	await _frames(30)
	_check(bat.position == frozen_position, "Pause freezes the flying enemy")
	game.restart_journey()
	_check(bat.health == 2 and bat.position == bat.home and bat.state == &"patrol", "Restart clears bat combat and returns it to its roost")
	if failures.is_empty():
		print("PASS: All forest expansion checks passed.")
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

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _capture(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
