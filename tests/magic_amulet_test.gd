extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/magic_amulet_test.gd
## Omit --headless and add -- --capture for reveal and healing screenshots.

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
	var island: StaticBody2D = game.forest.amulet_island
	var pickup: MagicAmulet = game.forest.amulet_pickup
	_check(island.position == Vector2(3170, -125) and island.collision_layer == 8, "A floating amulet island waits beyond the rightmost upper platform")
	_check(not prince.has_amulet and prince.magic == 0.0 and not game.magic_bar.visible and pickup.visible, "The magic bar stays hidden before collecting the amulet")
	prince.position = Vector2(2820, -101)
	game.forest.camera.position = Vector2(3040, 100)
	game.forest.camera.reset_smoothing()
	await _frames(3)
	await _capture("amulet-island")
	# Walking off the branch must miss the island even at full speed.
	prince.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("move_right")
	var walked_onto_island := false
	for i in range(70):
		await _frames(1)
		for j in range(prince.get_slide_collision_count()):
			if prince.get_slide_collision(j).get_collider() == island:
				walked_onto_island = true
	Input.action_release("move_right")
	_check(not walked_onto_island and not pickup.collected and prince.position.y > island.position.y + 80.0, "Walking off the upper platform falls short of the island")
	# Build a short run-up before jumping from near the branch edge.
	prince.position = Vector2(2820, -101)
	prince.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("move_right")
	await _frames(12)
	Input.action_press("jump")
	for i in range(80):
		await _frames(1)
		if pickup.collected:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(pickup.collected and prince.has_amulet, "Jumping from the rightmost upper platform collects the amulet")
	_check(game.mode == &"item_reveal" and paused and game.amulet_reveal.visible, "Collecting the amulet pauses play for its unlock animation")
	_check(game.reveal_art.texture != null and game.reveal_copy.text == "Allows the user the magic of healing.", "Unlock animation presents the amulet and healing description")
	_check(game.magic_bar.visible and game.magic_bar.value == 0.0 and game.combat_panel.size.y == 58.0, "Collecting introduces an initially empty blue magic bar")
	var magic_fill: StyleBoxFlat = game.magic_bar.get_theme_stylebox("fill")
	_check(magic_fill.bg_color.b > magic_fill.bg_color.r and magic_fill.bg_color.b > magic_fill.bg_color.g, "The new magic bar is blue")
	await _frames(70)
	await _capture("amulet-unlock")
	await _frames(160)
	_check(game.mode == &"playing" and not paused and not game.amulet_reveal.visible, "Unlock animation finishes and returns control")
	var landed_after_jump := false
	for i in range(prince.get_slide_collision_count()):
		if prince.get_slide_collision(i).get_collider() == island:
			landed_after_jump = true
	_check(prince.is_on_floor() and landed_after_jump, "The running jump lands safely on the island after collecting the amulet")

	# Feet must settle on the painted moss, not the transparent space above it.
	for offset_x in [-125.0, 0.0, 125.0]:
		prince.position = island.position + Vector2(offset_x, -70)
		prince.velocity = Vector2.ZERO
		await _frames(40)
		var supported_by_island := false
		for i in range(prince.get_slide_collision_count()):
			if prince.get_slide_collision(i).get_collider() == island:
				supported_by_island = true
		_check(prince.is_on_floor() and supported_by_island, "Island supports landings across its mossy deck at x=%s" % offset_x)
		_check(prince.position.y > island.position.y + 42.0 and prince.position.y < island.position.y + 45.0, "Feet meet the visible moss surface at x=%s" % offset_x)
	prince.position = island.position + Vector2(0, -70)
	prince.velocity = Vector2.ZERO
	await _frames(40)
	await _capture("amulet-island-landing")
	Input.action_press("move_right")
	await _frames(48)
	Input.action_release("move_right")
	_check(not prince.is_on_floor() and prince.velocity.y > 0.0 and prince.position.y > island.position.y + 60.0, "Walking past the island edge makes the prince fall naturally")
	# One-way collision allows ascent from below, then catches the descent.
	prince.position = island.position + Vector2(0, 175)
	prince.velocity = Vector2(0, -720)
	var rose_through_deck := false
	for i in range(40):
		await _frames(1)
		if prince.velocity.y < 0.0 and prince.position.y < island.position.y + 43.0:
			rose_through_deck = true
			break
	_check(rose_through_deck, "Jumping from below passes through the island deck")
	await _frames(55)
	_check(prince.is_on_floor() and absf(prince.position.y - (island.position.y + 43.29)) < 1.0, "Descending after passing through lands back on the moss")

	# Only confirmed sword damage fills magic.
	prince.equip_sword()
	prince.position = Vector2(2950, 586)
	prince.velocity = Vector2.ZERO
	var enemy: CharacterBody2D = game.forest.enemies[0]
	enemy.position = Vector2(3025, 586)
	enemy.set_physics_process(false)
	await _frames(3)
	for i in range(2):
		_check(prince.attack(), "Sword hit %d starts" % (i + 1))
		await _frames(14)
		await _frames(18)
	_check(enemy.health == 2 and prince.magic == ForestPrince.HEAL_MAGIC_COST and game.magic_bar.value == ForestPrince.HEAL_MAGIC_COST, "Two successful hits generate enough magic for one heal")
	var magic_before := prince.magic
	prince.position = Vector2(2700, 586)
	await _frames(3)
	prince.attack()
	await _frames(20)
	_check(prince.magic == magic_before, "A missed attack generates no magic")
	await _frames(20)

	# Healing requires a held focus and spends magic only on completion.
	prince.health = 50
	prince.health_changed.emit(prince.health, ForestPrince.MAX_HEALTH)
	var start_position := prince.position
	Input.action_press("heal")
	await _frames(28)
	_check(prince.is_healing and prince.position.distance_to(start_position) < 1.0 and prince.magic == magic_before and prince.health == 50, "Holding heal focuses in place without spending magic early")
	await _capture("healing-focus")
	Input.action_release("heal")
	await _frames(2)
	_check(not prince.is_healing and prince.magic == magic_before and prince.health == 50, "Releasing early cancels healing without a cost")
	Input.action_press("heal")
	await _frames(58)
	Input.action_release("heal")
	_check(not prince.is_healing and prince.health == 80 and prince.magic == 0.0 and game.health_bar.value == 80 and game.magic_bar.value == 0.0, "A completed focus spends 40 magic and restores 30 health")

	# Damage interrupts focus and preserves unspent magic.
	prince._set_magic(ForestPrince.HEAL_MAGIC_COST)
	prince.health = 60
	prince.health_changed.emit(prince.health, ForestPrince.MAX_HEALTH)
	prince.invulnerable_left = 0.0
	await _frames(5)
	Input.action_press("heal")
	await _frames(20)
	_check(prince.is_healing, "A second healing focus begins")
	_check(prince.take_damage(10, prince.position + Vector2(80, 0)), "Damage lands during the healing focus")
	Input.action_release("heal")
	await _frames(2)
	_check(not prince.is_healing and prince.health == 50 and prince.magic == ForestPrince.HEAL_MAGIC_COST, "Damage interrupts healing without consuming magic")

	game.restart_journey()
	await _frames(3)
	_check(not prince.has_amulet and prince.magic == 0.0 and not game.magic_bar.visible and game.combat_panel.size.y == 41.0, "Restart removes magic and restores the compact two-bar HUD")
	_check(not pickup.collected and pickup.visible, "Restart returns the amulet to its island")
	if failures.is_empty():
		print("PASS: All magic amulet checks passed.")
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
