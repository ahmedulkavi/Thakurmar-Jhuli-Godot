extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var prince: ForestPrince = game.forest.player
	for enemy in game.forest.enemies + game.forest.bats:
		enemy.set_physics_process(false)
	await _frames(5)
	_check(prince.stance == &"royal" and prince.defense == 0 and game.stance_icon.texture == game.ROYAL_STANCE_ICON, "Royal starts equipped")
	_key(KEY_RIGHT)
	await _frames(2)
	_check(prince.stance == &"royal", "Steel is locked before purchase")
	game.forest.has_steel_stance = true
	_key(KEY_RIGHT)
	await _frames(2)
	_check(prince.stance == &"steel" and prince.defense == 75 and game.stance_icon.texture == game.STEEL_STANCE_ICON and prince.stance_flash_left > 0, "Right equips Steel with flash and HUD")
	_check(prince.animation.sprite_frames == prince.steel_unarmed and prince.animation.modulate == Color.WHITE, "Unarmed Steel uses its own untinted artwork")
	prince.has_sword = true
	prince._update_combat_visuals()
	_check(prince.combat_visual.steel_equipped and prince.combat_visual.frames[0].atlas == prince.combat_visual.STEEL_SHEET, "Steel combat uses silver equipment artwork")
	Input.action_press("move_right")
	await _frames(12)
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.STEEL_WALK_SHEET and prince.combat_visual.art.modulate == Color.WHITE, "Steel movement uses new untinted walking frames")
	Input.action_release("move_right")
	prince.velocity = Vector2.ZERO
	_check(prince.take_damage(25, Vector2.ZERO) and prince.health == 93, "Steel reduces damage by 75 percent with rounding")
	prince.invulnerable_left = 0
	prince.knockback_left = 0
	prince.has_sword = true
	var enemy: CharacterBody2D = game.forest.enemies[0]
	enemy.position = prince.position + Vector2(80, 0)
	await _frames(3)
	_check(prince.attack() and prince.counter_window_left > 0 and prince.swing_left == 0, "Steel attack opens counter window without a normal strike")
	await _frames(4)
	_check(enemy.health == enemy.MAX_HEALTH, "No counter fires without an incoming attack")
	var before: int = prince.health
	_check(prince.take_damage(25, enemy.global_position, enemy), "Incoming attack is countered")
	_check(prince.health == before and enemy.health == 0 and prince.swing_left > 0, "Counter blocks hit and defeats attacker")
	game.forest.recover_at_fountain()
	_check(prince.stance == &"steel" and prince.defense == 75, "Checkpoint recovery retains equipped stance")
	_joy(JOY_BUTTON_DPAD_LEFT)
	await _frames(2)
	_check(prince.stance == &"royal" and prince.defense == 0 and game.stance_icon.texture == game.ROYAL_STANCE_ICON and not prince.combat_visual.steel_equipped and prince.animation.sprite_frames == prince.royal_unarmed, "D-pad left equips Royal and restores its artwork")
	prince.invulnerable_left = 0
	var royal_health: int = prince.health
	_check(prince.take_damage(25, Vector2.ZERO) and prince.health == royal_health - 25, "Royal takes full damage")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_check(prince.stance == &"steel", "D-pad right equips Steel")
	game.forest.ladder.unlock()
	game.forest.ladder.reveal_elapsed = game.forest.ladder.REVEAL_DURATION
	prince.position = Vector2(game.forest.ladder.position.x, game.forest.ladder.BOTTOM_Y - 20)
	prince.velocity = Vector2.ZERO
	Input.action_press("move_up")
	await _frames(3)
	_check(prince.is_climbing and prince.climb_visual.art.modulate == Color.WHITE and prince.climb_visual.art.texture.atlas == prince.climb_visual.STEEL_SHEET, "Climbing uses the untinted Steel artwork")
	Input.action_release("move_up")
	game.restart_journey()
	_check(prince.stance == &"royal" and not game.forest.has_steel_stance, "New journey resets stance and unlock")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All stance checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventJoypadButton.new()
	event.button_index = button
	Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
