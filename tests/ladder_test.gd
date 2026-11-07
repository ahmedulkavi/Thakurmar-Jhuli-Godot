extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/ladder_test.gd

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
	var ladder: ForestLadder = game.forest.ladder
	_check(not ladder.active and not ladder.visible and game.forest.upper_platforms.size() == 4, "The single ladder begins locked")
	_check(game.forest.upper_platforms.all(func(platform: StaticBody2D) -> bool: return platform.visible and platform.collision_layer == 8), "The raised route is present before the bats are defeated")
	_check(ladder.position == Vector2(2280, ForestLadder.TOP_Y) and ForestLadder.BOTTOM_Y == 330.0, "The ladder begins on the highest central platform")
	_check(game.forest.upper_platforms[1].position == Vector2(2280, ForestLadder.TOP_Y), "The ladder leads to a broad raised deck")
	_check(game.forest.bats.all(func(bat: CharacterBody2D) -> bool: return absf(bat.home.x - ladder.position.x) <= 310.0), "All three bats guard the central staircase where the reveal can be seen")
	prince.position = Vector2(2280, 586)
	Input.action_press("move_up")
	await _frames(10)
	Input.action_release("move_up")
	_check(not prince.is_climbing and prince.position.y > 580.0, "Up input cannot climb before the bats are defeated")
	for i in range(2):
		game.forest.bats[i].take_damage(2, prince.position)
	await _frames(2)
	_check(not ladder.active, "The ladder stays locked until the last bat is defeated")
	game.forest.bats[2].take_damage(2, prince.position)
	await _frames(2)
	_check(ladder.active and ladder.visible and ladder.reveal_elapsed > 0.0 and ladder.reveal_elapsed < ForestLadder.SMOKE_DURATION, "Defeating all three bats reveals one ladder with a smoky poof")
	_check(game.forest.upper_platforms.all(func(platform: StaticBody2D) -> bool: return platform.visible and platform.collision_layer == 8), "Raised platforms remain in place when the ladder appears")
	await _capture("ladder-unlocked")
	await _frames(16)
	await _capture("ladder-smoke")
	await _frames(34)
	_check(ladder.ready_for_climb(), "The ladder becomes climbable after its reveal")
	prince.position = Vector2(2280, ForestLadder.BOTTOM_Y)
	prince.velocity = Vector2.ZERO
	await _frames(2)
	Input.action_press("move_up")
	var up_poses: Dictionary = {}
	for i in range(50):
		await _frames(1)
		up_poses[prince.climb_visual.pose_frame] = true
	_check(up_poses.size() == 4 and prince.climb_visual.visible and not prince.animation.visible, "Climb-up sheet plays four distinct poses")
	await _capture("ladder-climb-up")
	Input.action_release("move_up")
	var ladder_x := prince.position.x
	var ladder_y := prince.position.y
	for action in ["move_left", "move_right"]:
		Input.action_press(action)
		await _frames(8)
		Input.action_release(action)
		_check(prince.is_climbing and absf(prince.position.x - ladder_x) < 0.1 and absf(prince.position.y - ladder_y) < 0.1, "%s does not move or detach the climbing prince" % action)
	Input.action_press("move_up")
	var hands_supported := true
	var captured_top := false
	# Highest hand in each painted upward pose, relative to the feet.
	var hand_offsets := [-116.4, -125.5, -137.9, -141.4]
	for i in range(80):
		await _frames(1)
		if prince.is_climbing:
			var hand_y: float = prince.position.y + hand_offsets[prince.climb_visual.pose_frame]
			hands_supported = hands_supported and hand_y >= ladder.position.y + ladder.rail_top()
			if not captured_top and prince.position.y < ForestLadder.TOP_Y + 18.0:
				captured_top = true
				await _capture("ladder-top-handrails")
	_check(captured_top and hands_supported, "Visible handrails support every upward pose through the final step onto the deck")
	_check(not prince.is_climbing and prince.collision_mask == 9 and prince.is_on_floor() and absf(prince.position.y - ForestLadder.TOP_Y) < 2.0, "Holding up automatically steps off onto the top deck without re-entering")
	Input.action_release("move_up")
	Input.action_press("move_down")
	var down_poses: Dictionary = {}
	for i in range(50):
		await _frames(1)
		down_poses[prince.climb_visual.pose_frame] = true
	Input.action_release("move_down")
	_check(prince.is_climbing and prince.position.y > 150.0 and prince.position.y < 190.0, "Down input descends the ladder")
	_check(down_poses.size() == 4 and down_poses.keys().all(func(frame: int) -> bool: return frame >= 4), "Climb-down sheet plays its own four poses")
	await _capture("ladder-climb-down")
	Input.action_press("move_down")
	Input.action_press("move_left")
	await _frames(8)
	Input.action_release("move_left")
	_check(prince.is_climbing and absf(prince.position.x - ladder_x) < 0.1, "Left input is ignored while descending")
	await _frames(65)
	_check(not prince.is_climbing and prince.collision_mask == 9 and prince.is_on_floor() and absf(prince.position.y - ForestLadder.BOTTOM_Y) < 2.0, "Holding down automatically steps off onto the lower branch without re-entering")
	Input.action_release("move_down")
	Input.action_press("move_up")
	await _frames(115)
	Input.action_release("move_up")
	_check(not prince.is_climbing and prince.is_on_floor() and absf(prince.position.y - ForestLadder.TOP_Y) < 2.0, "The ladder can be climbed again after stepping off at the bottom")
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(prince.is_on_floor() and prince.position.x > 2350.0, "The raised deck has room to walk before jumping")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(39)
	Input.action_release("move_right")
	await _frames(27)
	Input.action_release("jump")
	await _frames(2)
	_check(prince.is_on_floor() and absf(prince.position.y + 50.0) < 3.0 and absf(prince.position.x - 2590.0) < 75.0, "The next upper platform is reachable by a normal jump")
	await _capture("ladder-upper-platforms")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(42)
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(24)
	_check(prince.is_on_floor() and absf(prince.position.y + 100.0) < 3.0 and absf(prince.position.x - 2820.0) < 75.0, "A second raised platform is reachable by jumping")
	prince.position = Vector2(2280, ForestLadder.TOP_Y)
	prince.velocity = Vector2.ZERO
	await _frames(2)
	Input.action_press("move_down")
	await _frames(4)
	Input.action_release("move_down")
	_check(prince.is_climbing and prince.position.y > ForestLadder.TOP_Y and prince.climb_visual.pose_frame >= 4, "Down input can re-enter the ladder from its top platform")
	game.pause_journey()
	var frozen_y := prince.position.y
	await _frames(30)
	_check(prince.position.y == frozen_y and ladder.active, "Pause freezes the upper route")
	game.restart_journey()
	await _frames(2)
	_check(not ladder.active and not ladder.visible and not prince.is_climbing and prince.collision_mask == 9, "Restart hides the ladder and clears climbing state")
	_check(game.forest.upper_platforms.all(func(platform: StaticBody2D) -> bool: return platform.visible and platform.collision_layer == 8), "Restart preserves the raised route")
	if failures.is_empty():
		print("PASS: All ladder checks passed.")
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
