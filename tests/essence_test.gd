extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/essence_test.gd
## Omit --headless and add -- --capture to inspect the drop and counter.

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
	_check(game.forest.essence == 0 and game.essence_count.text == "0", "A new journey starts with zero Essence in the HUD")
	var icon := game.frame.get_node("EssenceCounter/EssenceIcon") as TextureRect
	_check(icon.size == Vector2(40, 40), "The Essence icon fits inside the counter")
	var counter := game.frame.get_node("EssenceCounter") as Panel
	_check(counter.size.x == 120.0 and counter.get_children().size() == 2, "Compact counter shows only the coin icon and amount")
	prince.position = Vector2(1200, 586)
	prince.velocity = Vector2.ZERO
	var shade: CharacterBody2D = game.forest.enemies[0]
	shade.position = Vector2(1400, 586)
	shade.take_damage(3, prince.position)
	await _frames(2)
	_check(game.forest.essence_drops.get_child_count() == 0, "Damaging a living enemy does not drop Essence")
	shade.take_damage(1, prince.position)
	shade.take_damage(1, prince.position)
	await _frames(5)
	_check(game.forest.essence_drops.get_child_count() == 1 and game.forest.essence == 0, "A defeat drops exactly one uncollected coin")
	var drop: CharacterBody2D = game.forest.essence_drops.get_child(0)
	_check(drop.amount == 25, "A harder shade drops 25 Essence")
	var scale_before: float = drop.coin_art.scale.x
	await _frames(10)
	_check(not is_equal_approx(drop.coin_art.scale.x, scale_before), "The dropped coin rotates")
	game.forest.camera.position = Vector2(1450, 360)
	game.forest.camera.reset_smoothing()
	await _capture("essence-drop")
	game.pause_journey()
	var paused_age: float = drop.age
	await _frames(25)
	_check(drop.age == paused_age and game.forest.essence == 0, "Pause freezes the rotating drop and collection")
	game.resume_journey()
	prince.position = Vector2(1400, 586)
	prince.velocity = Vector2.ZERO
	await _frames(40)
	_check(game.forest.essence == 25 and game.essence_count.text == "25" and game.forest.essence_drops.get_child_count() == 0, "Touching the coin collects it once and updates the counter")
	_check(game.mode == &"item_reveal" and paused and game.reveal_art.texture == game.ESSENCE_COIN and game.reveal_title.text == "ESSENCE DISCOVERED" and game.reveal_copy.text == "Essence is gathered from the spirits of fallen foes.", "First Essence pickup presents the coin and its description")
	await _frames(70)
	await _capture("essence-discovered")
	var skip := InputEventKey.new()
	skip.keycode = KEY_SPACE
	skip.physical_keycode = KEY_SPACE
	skip.pressed = true
	Input.parse_input_event(skip)
	await _frames(2)
	skip.pressed = false
	Input.parse_input_event(skip)
	_check(game.mode == &"playing" and not paused and game.forest.essence == 25, "The first Essence reveal can be skipped without losing the reward")
	var bat: CharacterBody2D = game.forest.bats[3]
	bat.position = Vector2(1700, 450)
	bat.take_damage(2, prince.position)
	await _frames(110)
	_check(game.forest.essence_drops.get_child_count() == 1, "A flying enemy drops a coin")
	drop = game.forest.essence_drops.get_child(0)
	_check(drop.amount == 10 and absf(drop.position.y - 586.0) < 3.0 and drop.is_on_floor(), "A regular bat drops 10 Essence and its coin falls onto the ground")
	prince.position = Vector2(1700, 586)
	prince.velocity = Vector2.ZERO
	await _frames(35)
	_check(game.forest.essence == 35 and game.essence_count.text == "35" and game.mode == &"playing", "Later Essence pickups update the total without repeating the reveal")
	var guardian: CharacterBody2D = game.forest.ladder_guardians[0]
	guardian.position = Vector2(1200, 470)
	guardian.take_damage(2, prince.position)
	await _frames(65)
	drop = game.forest.essence_drops.get_child(0)
	_check(drop.amount == 15, "A special guardian bat drops 15 Essence")
	prince.position = Vector2(1200, 586)
	prince.velocity = Vector2.ZERO
	await _frames(35)
	_check(game.forest.essence == 50 and game.essence_count.text == "50", "Guardian Essence is collected and displayed")
	# A reset during a deferred death must not create a stale extra coin.
	prince.position = Vector2(game.forest.FOUNTAIN_X - 60.0, game.forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	var another: CharacterBody2D = game.forest.enemies[1]
	another.take_damage(4, prince.position)
	_check(game.forest.try_rest(), "The fountain can be used after earning Essence")
	await _frames(5)
	_check(game.forest.essence == 50 and game.essence_count.text == "50" and game.forest.essence_drops.get_child_count() == 0, "Rest keeps collected Essence and clears uncollected or pending drops")
	prince.stop_resting()
	prince.take_damage(1000, prince.position + Vector2(100, 0))
	game.primary.pressed.emit()
	await _frames(5)
	_check(game.forest.essence == 50 and game.essence_count.text == "50" and game.forest.has_discovered_essence, "Checkpoint retry preserves collected Essence and its discovery")
	game.restart_journey()
	await _frames(5)
	_check(game.forest.essence == 0 and game.essence_count.text == "0" and game.forest.essence_drops.get_child_count() == 0 and not game.forest.has_discovered_essence, "A new journey clears Essence, drops and discovery")
	game.forest._on_essence_collected(10)
	await _frames(240)
	_check(game.mode == &"playing" and not paused and game.forest.essence == 10, "The first reveal in a new journey finishes automatically")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All Essence checks passed.")
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
