extends SceneTree

var failures: Array[String] = []
var game: Control
var prince: ForestPrince
var rival: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	prince = game.forest.player
	rival = game.forest.underwater.boss
	for enemy in game.forest.enemies + game.forest.bats + game.forest.underwater.enemies:
		enemy.set_physics_process(false)
	prince.set_physics_process(false)
	rival.set_physics_process(false)
	game.mode = &"playing"
	paused = false
	await _frames(3)
	rival.position = Vector2(18000, 1100)
	prince.position = rival.position + Vector2.LEFT * 280
	prince.god_mode = false
	rival.active = true
	rival.collision_layer = 4
	rival.beat = 3
	rival.facing = 1
	rival._set_stance(3)
	rival._begin_beat()
	var motion: Node2D = rival.urumi
	_check(motion.visible and not rival.visual.visible and motion.frames.size() == 16, "Twin urumi uses its own full-body animation sheet")
	var visited: Array[int] = []
	var hands: Array[Vector2] = []
	for phase in [&"windup", &"sweep", &"recover"]:
		var count := 8 if phase == &"sweep" else 4
		for index in range(count):
			motion.show_phase(phase, (index + 0.5) / count, 1.0)
			visited.append(motion.pose_frame)
			hands.append(motion.grip(0))
			for blade in range(2):
				var ribbon: PackedVector2Array = motion.ribbon(blade)
				_check(ribbon[0].is_equal_approx(motion.grip(blade)), "Rendered blade begins at its animated hilt")
				var length := 0.0
				for point in range(1, ribbon.size()):
					length += ribbon[point].distance_to(ribbon[point - 1])
				_check(absf(length - motion.BLADE_LENGTH) < 0.01, "Flexible steel coils and unfurls without changing blade length")
			var right: PackedVector2Array = motion.ribbon(0).duplicate()
			motion.show_phase(phase, (index + 0.5) / count, -1.0)
			var left: PackedVector2Array = motion.ribbon(0)
			for point in range(right.size()):
				_check(left[point].is_equal_approx(Vector2(-right[point].x, right[point].y)), "Hand and blade geometry mirror together")
			_check(motion.art.flip_h, "Full-body pose mirrors with its blades")
			motion.show_phase(phase, (index + 0.5) / count, 1.0)
	_check(visited == range(16), "Windup, strike and recovery play all sixteen frames in order")
	var min_y := 0.0
	var max_y := -200.0
	for at in hands:
		min_y = minf(min_y, at.y)
		max_y = maxf(max_y, at.y)
	_check(max_y - min_y > 35.0, "The hand moves through a visible overhead-to-low sweep")
	motion.show_phase(&"windup", 0.5, 1.0)
	_check(not motion.is_striking(), "Windup loops are harmless")
	motion.show_phase(&"recover", 0.5, 1.0)
	_check(not motion.is_striking(), "Gathering the blades in recovery is harmless")
	for facing in [-1.0, 1.0]:
		rival.facing = facing
		rival.state = &"whip"
		rival.left = rival.SWEEP_TIME * 0.5
		rival.hit = false
		motion.show_phase(&"sweep", 0.5, facing)
		var points: PackedVector2Array = motion.ribbon(0)
		var contact: Vector2 = points[36]
		prince.position = rival.position + contact + Vector2(0, 61)
		prince.health = prince.MAX_HEALTH
		prince.invulnerable_left = 0.0
		rival._physics_process(0.0)
		_check(absf(contact.x) > 200.0 and prince.health == prince.MAX_HEALTH - 20, "Visible flexible blade deals damage beyond sword range in either direction")
		prince.invulnerable_left = 0.0
		rival._physics_process(0.0)
		_check(prince.health == prince.MAX_HEALTH - 20, "A twin sweep damages the player only once")
		prince.position = rival.position + Vector2(facing * 600, 0)
		rival.hit = false
		rival._physics_process(0.0)
		_check(not rival.hit, "Outside the rendered blade path is safe")
	rival.facing = 1
	rival.state = &"whip"
	rival.left = rival.SWEEP_TIME * 0.5
	motion.show_phase(&"sweep", 0.5, 1.0)
	motion.tick(0.016)
	_check(not motion.trails.is_empty(), "Sweep leaves brief blade trails")
	rival._recover(rival.URUMI_RECOVERY)
	_check(motion.phase == &"recover" and motion.pose_frame == 12, "Recovery begins with a new hand pose instead of freezing the attack")
	rival.set_physics_process(true)
	paused = true
	var frozen_frame: int = motion.pose_frame
	var remaining: float = rival.left
	await _frames(5)
	_check(motion.pose_frame == frozen_frame and is_equal_approx(rival.left, remaining), "Pause freezes hand animation and attack timers together")
	paused = false
	rival.set_physics_process(false)
	rival._set_stance(2)
	_check(not motion.visible and motion.trails.is_empty() and rival.visual.visible, "A Steel interruption removes urumi poses and blade trails")
	rival.beat = 3
	rival._begin_beat()
	rival.reset_boss()
	_check(not motion.visible and motion.trails.is_empty(), "Encounter reset clears the urumi animation")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: Urumi hand motion, blade attachment, mirrored hits, recovery and pause checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
