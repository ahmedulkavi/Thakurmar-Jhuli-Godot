extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	var forest: ForestLevel = game.forest
	var prince: ForestPrince = forest.player
	var hunter_image: Image = prince.combat_visual.HUNTER_SHEET.get_image()
	_check(hunter_image.get_pixel(188, 83).a > 0.9 and hunter_image.get_pixel(240, 180).a > 0.9, "Hunter face and hand pixels retain opaque skin")
	for enemy in forest.enemies + forest.bats:
		enemy.set_physics_process(false)
	await _frames(4)
	_check(not forest.purchase_hunter_stance(), "Hunter cannot be bought before the boss essence is collected")
	forest._on_boss_victory()
	_check(forest.get_node_or_null("ShakchunniEssence") != null and game.mode == &"playing", "Boss drops a unique collectible and the journey continues")
	prince.position = forest.boss_arena.boss.position
	await _frames(5)
	_check(forest.has_shakchunni_essence and game.mode == &"item_reveal" and game.reveal_copy.text == "When the hunter becomes prey, an apex hunter is born.", "Essence of Shakchunni shows its description")
	game._finish_item_reveal()
	forest._set_essence(200)
	prince.position = Vector2(forest.FOUNTAIN_X - 60, forest.GROUND_Y)
	await _frames(4)
	_check(forest.try_rest(), "Prince can rest after the boss")
	game._open_merchant()
	_check(not game.merchant_hunter.disabled, "Hunter appears purchasable after essence collection")
	var requirement_icon := game.merchant_hunter.get_node("ShakchunniEssenceIcon") as TextureRect
	var cost_label := game.merchant_hunter.get_node("CostLabel") as Label
	_check(requirement_icon.texture == game.SHAKCHUNNI_ESSENCE_ICON and cost_label.text == "200 Essence" and not game.merchant_status.text.contains("Hunter requires"), "Hunter card shows its unique essence and priced Essence cost")
	game._buy_hunter_stance()
	_check(forest.has_hunter_stance and forest.essence == 0 and game.reveal_copy.text == "Hunt from afar with spirit arrows and evade danger with a swift roll.", "Hunter purchase describes its abilities")
	game._finish_item_reveal()
	game._close_merchant()
	game._leave_rest()
	prince.equip_sword()
	_key(KEY_UP)
	await _frames(3)
	_check(prince.stance == &"hunter" and game.stance_icon.texture == game.HUNTER_STANCE_ICON and game.magic_bar.visible, "Up equips green Hunter and displays magic")
	_check(prince.climb_visual.frames[0].atlas == prince.climb_visual.HUNTER_SHEET, "Hunter equips its climbing artwork")
	var before_magic: float = prince.magic
	await _frames(60)
	_check(prince.magic > before_magic, "Hunter magic regenerates over time")
	prince.position = Vector2(3000, forest.GROUND_Y)
	prince.facing = 1.0
	prince._set_magic(60)
	var enemy: CharacterBody2D = forest.enemies[0]
	enemy.position = prince.position + Vector2(250, 0)
	var before_health: int = enemy.health
	_check(prince.attack() and prince.magic == 40, "Arrow spends 20 magic")
	await _frames(20)
	_check(enemy.health == before_health - 1, "Arrow damages the enemy in front")
	prince._set_magic(40)
	_check(prince.roll() and prince.stamina == 70 and prince.magic == 40 and prince.invulnerable_left > 0.0, "Roll spends 30 stamina and preserves magic")
	var before_x: float = prince.position.x
	await _frames(8)
	_check(prince.position.x > before_x, "Roll moves the prince forward")
	await _frames(30)
	prince._set_stamina(29)
	_check(not prince.roll(), "Roll requires sufficient stamina")
	prince._set_stamina(60)
	prince._set_magic(40)
	Input.action_press("heal")
	await _frames(1)
	Input.action_release("heal")
	_check(prince.roll_left > 0.0 and prince.stamina < 31 and prince.magic > 40, "Magic button starts a stamina-funded Hunter roll")
	forest.recover_at_fountain()
	_check(forest.has_hunter_stance and forest.has_shakchunni_essence and prince.stance == &"hunter", "Checkpoint retains Hunter and boss essence")
	game.restart_journey()
	_check(not forest.has_hunter_stance and not forest.has_shakchunni_essence and prince.stance == &"royal", "New journey resets Hunter and boss essence")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: Hunter stance checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
