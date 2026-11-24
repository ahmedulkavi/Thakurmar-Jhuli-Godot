extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	var water: Node2D = game.forest.underwater
	var prince: ForestPrince = game.forest.player
	var boss: CharacterBody2D = water.boss
	for enemy in game.forest.enemies + game.forest.bats + water.enemies:
		enemy.set_physics_process(false)
	boss.set_physics_process(false)
	prince.god_mode = true
	prince.position = Vector2(boss.ENTRY_X - 60, prince.HALL_FLOOR_Y)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	_check(water.can_enter() and water.fog_prompt.visible, "Fog offers entry on the dry hall floor")
	Input.action_press("move_right")
	await _frames(45)
	Input.action_release("move_right")
	_check(prince.position.x < boss.ENTRY_X and not boss.active, "Walking cannot bypass the fog or start the boss")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	game._input(interact)
	await _frames(3)
	_check(boss.active and prince.position.x > boss.ENTRY_X and not water.gate_collision.disabled, "Interact traverses the fog and seals combat")
	_check(not water.traverse(), "An active encounter cannot traverse again")
	Input.action_press("move_left")
	await _frames(80)
	_check(prince.position.x > boss.ENTRY_X and boss.active, "Running left cannot retreat through the sealed gate")
	Input.action_press("jump")
	await _frames(60)
	Input.action_release("jump")
	Input.action_release("move_left")
	_check(prince.position.x > boss.ENTRY_X, "Jumping cannot bypass the fog")
	boss.take_damage(boss.MAX_HEALTH, prince.position)
	await _frames(3)
	_check(water.gate_collision.disabled, "Defeating the boss opens the gate")
	# Victory pauses the journey; resume physics to check the open passage.
	paused = false
	game.mode = &"playing"
	Input.action_press("move_left")
	await _frames(45)
	Input.action_release("move_left")
	_check(prince.position.x < boss.ENTRY_X, "The opened gate allows return to the fountain")
	game.forest.checkpoint = game.forest.PALACE_FOUNTAIN
	game.forest.recover_at_fountain()
	await _frames(3)
	_check(not water.gate_collision.disabled and not boss.active and boss.health == boss.MAX_HEALTH, "Checkpoint retry restores the boss and closed fog")
	prince.position = Vector2(boss.ENTRY_X - 60, prince.HALL_FLOOR_Y)
	await _frames(5)
	_check(water.traverse(), "The gate permits a fresh encounter after reset")
	game.restart_journey()
	await _frames(3)
	_check(not water.gate_collision.disabled and not boss.active, "Restart clears combat and restores the gate")
	if failures.is_empty():
		print("PASS: Boss 2 fog entry, combat restriction, victory, and reset")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures.append(message)
