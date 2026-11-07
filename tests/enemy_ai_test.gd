extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/enemy_ai_test.gd
## Omit --headless and add -- --capture for enemy action screenshots.

var game: Control
var prince: ForestPrince
var enemy: CharacterBody2D
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
	prince.set_physics_process(false)
	enemy = game.forest.enemies[0]
	game.forest.enemies[1].set_physics_process(false)
	for bat in game.forest.bats:
		bat.set_physics_process(false)
	await _place(Vector2(1200, 586), Vector2(1040, 586))
	_check(enemy.aggroed and enemy.state == &"chase", "Visible prince triggers pursuit")
	var walked: Dictionary = {}
	for i in range(35):
		await _frames(1)
		if enemy.state == &"chase":
			walked[enemy.visual.pose_frame] = true
	_check(walked.size() >= 2, "Pursuit cycles through painted walking poses")

	# Every original obstacle, both directions, using real collision and AI.
	for obstacle in [["log", 910.0], ["rocks", 1810.0], ["root", 2650.0]]:
		for direction in [1.0, -1.0]:
			await _test_obstacle(obstacle[0], obstacle[1], direction)

	await _place(Vector2(2440, 586), Vector2(500, 586))
	await _frames(100)
	_check(not enemy.aggroed and enemy.jumps_performed == 0 and enemy.position.distance_to(enemy.home) < 1.0, "An idle shade does not jump at nearby obstacles without aggro")

	# A tall wall blocks sight and cannot be cleared by repeated jumps.
	var wall := _barrier(Vector2(1400, 586), Vector2(40, 360))
	await _place(Vector2(1200, 586), Vector2(1560, 586))
	await _frames(20)
	_check(not enemy.aggroed, "Shade does not acquire the prince through a solid wall")
	await _place(Vector2(1200, 586), Vector2(1040, 586))
	_check(enemy.aggroed, "Shade acquires the prince before he moves behind cover")
	prince.position = Vector2(1560, 586)
	await _frames(75)
	_check(enemy.aggroed and enemy.memory_left > 0.0, "Aggro persists briefly after losing sight behind cover")
	_check(enemy.jumps_performed == 0 and enemy.position.x < 1345.0, "Tall wall stops pursuit without impossible or repeated jumps")
	await _frames(210)
	_check(not enemy.aggroed, "Aggro memory expires when the prince stays hidden")
	await _frames(180)
	_check(enemy.position.distance_to(enemy.home) < 2.0 and enemy.state == &"idle", "Shade returns home and settles after losing the target")
	wall.queue_free()
	await _frames(2)

	# A low overhang leaves standing room, but not enough room for a jump.
	var ceiling := _barrier(Vector2(875, 451), Vector2(420, 30))
	await _place(Vector2(690, 586), Vector2(540, 586))
	prince.position = Vector2(1130, 586)
	await _frames(130)
	_check(enemy.aggroed and enemy.jumps_performed == 0 and enemy.position.x < 805.0, "Low ceiling prevents jumping into an obstructed arc")
	ceiling.queue_free()
	await _frames(2)

	# Damage interrupts a windup; a hit also provokes an otherwise idle shade.
	await _place(Vector2(1200, 586), Vector2(1125, 586))
	_check(enemy.state == &"windup" and prince.health == 100, "Melee begins with a visible windup before damage")
	await _screenshot("enemy-attack-windup")
	enemy.take_damage(1, prince.position)
	await _frames(2)
	_check(enemy.state == &"hurt" and enemy.attack_left == 0.0 and enemy.visual.pose_frame == 14, "Sword hit interrupts attack and selects the recoil pose")
	await _frames(15)
	_check(prince.health == 100, "Interrupted attack cannot deal a delayed hit")
	await _place(Vector2(1200, 586), Vector2(1125, 586))
	var attack_frames := 5
	for i in range(30):
		await _frames(1)
		attack_frames += 1
		if enemy.state == &"lunge" and prince.health < 100:
			break
	_check(enemy.state == &"lunge" and enemy.visual.pose_frame in [7, 8] and prince.health == 75, "A committed swipe uses its attack poses and lands damage during the lunge")
	_check(attack_frames <= 20, "Faster windup connects within a third of a second at melee distance")
	await _screenshot("enemy-attack-swipe")
	await _frames(12)
	_check(enemy.state == &"recover" and enemy.visual.pose_frame == 9 and enemy.recovery_left > 0.0, "Attack recovery gives the prince a visible opening")
	await _frames(34)
	_check(enemy.state == &"windup", "Shorter recovery lets the shade begin another attack promptly")
	await _place(Vector2(1200, 586), Vector2(400, 586))
	enemy.take_damage(1, prince.position)
	_check(enemy.aggroed and enemy.memory_left > 0.0, "Taking damage immediately provokes the shade")
	await _frames(2)
	await _screenshot("enemy-hit-recoil")
	enemy.take_damage(5, prince.position)
	await _frames(2)
	_check(enemy.health == 0 and enemy.state == &"dead" and enemy.collision_layer == 0 and enemy.visual.pose_frame == 15, "Lethal hit removes collision and selects the collapse pose")
	await _screenshot("enemy-defeat")
	await _frames(28)
	_check(not enemy.visible, "Collapse fades out and stops the defeated shade")

	# Pause freezes AI and jump preparation; restart restores every state.
	await _place(Vector2(690, 586), Vector2(540, 586))
	prince.position = Vector2(1130, 586)
	for i in range(100):
		await _frames(1)
		if enemy.state == &"jump_windup":
			break
	_check(enemy.state == &"jump_windup", "Obstacle jump has a crouched anticipation state")
	game.pause_journey()
	var paused_position := enemy.position
	var windup: float = enemy.jump_windup_left
	await _frames(30)
	_check(enemy.position == paused_position and is_equal_approx(enemy.jump_windup_left, windup), "Pause freezes enemy movement and jump preparation")
	game.restart_journey()
	await _frames(3)
	_check(enemy.health == 4 and enemy.visible and not enemy.aggroed and enemy.jumps_performed == 0 and enemy.jump_windup_left == 0.0, "Restart clears aggro, jumps, death, and damage state")
	if failures.is_empty():
		print("PASS: All enemy AI checks passed.")
	else:
		for failure in failures:
			push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _place(at: Vector2, target: Vector2) -> void:
	game.restart_journey()
	enemy.home = at
	enemy.reset_enemy()
	prince.position = target
	prince.velocity = Vector2.ZERO
	await _frames(5)

func _test_obstacle(label: String, x: float, direction: float) -> void:
	var start := Vector2(x - direction * 230.0, 586)
	await _place(start, start - Vector2(direction * 150, 0))
	_check(enemy.aggroed, "%s (%s): shade acquires aggro" % [label, direction])
	prince.position = Vector2(x + direction * 230.0, 586)
	var anticipated := false
	var rose := false
	var fell := false
	var crossed := false
	var grounded_jumps := true
	var lowest_y: float = enemy.position.y
	var previous_grounded := enemy.is_on_floor()
	var previous_jumps: int = enemy.jumps_performed
	for i in range(260):
		await _frames(1)
		if enemy.jumps_performed > previous_jumps and not previous_grounded:
			grounded_jumps = false
		previous_grounded = enemy.is_on_floor()
		previous_jumps = enemy.jumps_performed
		lowest_y = minf(lowest_y, enemy.position.y)
		anticipated = anticipated or (enemy.state == &"jump_windup" and enemy.visual.pose_frame == 10)
		if enemy.jumping and enemy.velocity.y < -100.0 and enemy.visual.pose_frame == 11 and not rose:
			rose = true
			if label == "root" and direction > 0.0:
				await _screenshot("enemy-root-jump-rise")
		if enemy.jumping and enemy.velocity.y > 100.0 and enemy.visual.pose_frame == 12 and not fell:
			fell = true
			if label == "root" and direction > 0.0:
				await _screenshot("enemy-root-jump-fall")
		if (enemy.position.x - x) * direction > 120.0 and enemy.is_on_floor():
			crossed = true
			break
	_check(crossed and enemy.jumps_performed > 0, "%s (%s): aggroed shade jumps across and lands beyond the obstacle" % [label, direction])
	_check(anticipated and rose and fell and lowest_y < 486.0, "%s (%s): crouch, rise, and fall animation follow a real jump arc" % [label, direction])
	_check(grounded_jumps, "%s (%s): jumps only launch from the ground" % [label, direction])
	if not crossed:
		print("NAVIGATION DIAGNOSTICS: position=%s state=%s aggro=%s jumps=%s min_y=%s" % [enemy.position, enemy.state, enemy.aggroed, enemy.jumps_performed, lowest_y])

func _barrier(at: Vector2, dimensions: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = dimensions
	shape.shape = bounds
	shape.position.y = -dimensions.y * 0.5
	body.add_child(shape)
	game.forest.add_child(body)
	return body

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _screenshot(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		var followed_player: bool = game.forest.is_processing()
		game.forest.set_process(false)
		game.forest.camera.position.x = clampf(enemy.position.x + 120.0, 640.0, 3200.0)
		game.forest.camera.reset_smoothing()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
		game.forest.set_process(followed_player)
