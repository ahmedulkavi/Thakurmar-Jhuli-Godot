extends SceneTree
## Run with --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd

var game: Control
var prince: ForestPrince
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
	for bat in game.forest.bats:
		bat.set_physics_process(false)
	await _frames(5)
	_check(prince.health == 100 and game.health_bar.value == 100, "Health and HUD start full")
	_check(not prince.attack(), "Sword attacks require collecting the blade")
	_check(game.forest.enemies.size() >= 6, "Shades guard both the original and extended paths")
	prince.position = Vector2(300, 586)
	await _frames(40)
	await _screenshot("combat-pickup")
	_check(not prince.has_sword and game.forest.sword_pickup.visible, "Blade waits above the anvil platform")
	prince.position = Vector2(450, 380)
	await _frames(40)
	_check(prince.has_sword and prince.combat_visual.visible, "Landing at the anvil automatically equips the sword")
	_check(game.forest.sword_pickup.collected and not game.forest.sword_pickup.visible, "Collected sword disappears from the platform")
	_check(game.mode == &"item_reveal" and paused and game.amulet_reveal.visible and game.reveal_sword.visible and not game.reveal_art.visible, "Sword pickup opens its animated item reveal")
	_check(game.reveal_title.text == "FOREST BLADE AWAKENED" and game.reveal_copy.text == "Allows the user to wield the Forest Blade.", "Sword reveal describes the unlocked weapon")
	await _frames(50)
	await _screenshot("sword-unlock")
	await _frames(160)
	_check(game.mode == &"playing" and not paused and not game.amulet_reveal.visible, "Sword reveal returns control automatically")

	# Disable AI while isolating hit direction, reach, cooldown, and wall blocking.
	var front: CharacterBody2D = game.forest.enemies[0]
	var behind: CharacterBody2D = game.forest.enemies[1]
	front.set_physics_process(false)
	behind.set_physics_process(false)
	prince.position = Vector2(2920, 586)
	front.position = Vector2(3000, 586)
	behind.position = Vector2(2840, 586)
	await _frames(4)
	_key(KEY_J, true)
	await _frames(10)
	_key(KEY_J, false)
	_check(front.health == 3, "J swings and damages a shade in front")
	_check(behind.health == 4, "Right-facing attack does not hit a shade behind")
	_check(not prince.attack(), "Cooldown prevents an immediate repeated strike")
	await _screenshot("combat-swing")
	await _frames(10)
	_check(front.health == 3, "One swing hits each enemy only once")
	await _frames(12)
	_key(KEY_X, true)
	await _frames(12)
	_key(KEY_X, false)
	_check(front.health == 2, "X starts another swing after cooldown")
	await _frames(18)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await _frames(12)
	mouse.pressed = false
	Input.parse_input_event(mouse)
	_check(front.health == 1, "Stronger shade survives three hits, including mouse attack")
	await _frames(20)
	_key(KEY_J, true)
	await _frames(12)
	_key(KEY_J, false)
	_check(front.health == 0 and front.state == &"dead" and front.collision_layer == 0, "Fourth sword hit starts defeat and immediately removes the shade's hitbox")
	await _frames(24)
	if game.mode == &"item_reveal":
		_key(KEY_ENTER, true)
		_key(KEY_ENTER, false)
		await _frames(24)
	_check(not front.visible, "Defeated shade disappears after its collapse animation")
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	await _frames(4)
	await _wait_for_stamina()
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_X
	controller.pressed = true
	Input.parse_input_event(controller)
	await _frames(12)
	controller.pressed = false
	Input.parse_input_event(controller)
	_check(behind.health == 3, "Controller left face button strikes to the left when facing left")
	await _frames(20)
	behind.position = Vector2(prince.position.x - 190, 586)
	await _wait_for_stamina()
	_check(prince.attack(), "Out-of-reach check starts an affordable sword attack")
	await _frames(16)
	_check(behind.health == 3, "Sword cannot damage a shade outside its reach")
	await _frames(15)
	prince.position = Vector2(2550, 586)
	prince.facing = 1.0
	behind.position = Vector2(2650, 586)
	await _frames(3)
	await _wait_for_stamina()
	_check(prince.attack(), "Wall-blocking check starts an affordable sword attack")
	await _frames(15)
	_check(behind.health == 3, "Solid platform blocks sword hits through its body")

	# Damage affects the HUD, grants a grace period, and freezes with pause.
	prince.position = Vector2(2900, 586)
	prince.velocity = Vector2.ZERO
	_check(prince.take_damage(20, Vector2(2960, 586)), "Enemy damage is accepted")
	_check(prince.health == 80 and game.health_bar.value == 80, "Health bar updates immediately on damage")
	_check(not prince.take_damage(20, Vector2(2960, 586)) and prince.health == 80, "Invulnerability prevents repeated contact damage")
	_check(prince.velocity.x < 0.0, "Damage knocks the prince away from its source")
	await _frames(5)
	game.pause_journey()
	var grace := prince.invulnerable_left
	var swing := prince.swing_left
	await _frames(70)
	_check(is_equal_approx(prince.invulnerable_left, grace) and is_equal_approx(prince.swing_left, swing), "Pause freezes damage protection and swing timers")
	_check(not prince.attack() and not prince.take_damage(20, Vector2.ZERO), "Paused game rejects attacks and damage")
	game.resume_journey()
	await _frames(65)
	_check(prince.take_damage(20, Vector2(2960, 586)) and prince.health == 60, "Prince can take damage again after protection expires")

	# An actual enemy telegraphs and lunges without tests calling take_damage.
	game.restart_journey()
	front.set_physics_process(true)
	prince.position = Vector2(2935, 586)
	await _frames(5)
	_check(front.attack_left > front.ATTACK_ACTIVE_TIME and prince.health == 100, "Nearby shade visibly winds up before dealing damage")
	await _frames(40)
	_check(prince.health == 75, "Shade's faster lunge deals 25 damage through normal AI")
	await _screenshot("combat-damage")
	front.set_physics_process(false)
	await _frames(65)
	prince.take_damage(1000, front.position)
	_check(prince.health == 0 and game.health_bar.value == 0, "Lethal damage clamps health to zero")
	_check(paused and game.mode == &"defeated" and game.overlay.visible, "Lethal damage opens the retry screen and pauses gameplay")
	_check(not prince.attack(), "Defeated prince cannot attack")
	await _screenshot("combat-defeated")
	game.primary.pressed.emit()
	await _frames(5)
	_check(not paused and game.mode == &"playing" and prince.health == 100, "Try Again restores full health and resumes")
	_check(not prince.has_sword and game.forest.sword_pickup.visible and not game.forest.sword_pickup.collected, "Restart restores the sword pickup and clears the equipped weapon")
	_check(front.health == 4 and behind.health == 4 and front.visible and behind.visible, "Restart revives both shades at their stronger full health")
	_check(front.position.distance_to(front.home) < 1.0 and behind.position.distance_to(behind.home) < 1.0, "Restart returns shades to their original positions")
	prince.equip_sword()
	game.pause_journey()
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(3)
	_check(not paused and not prince.has_sword and prince.health == 100, "Keyboard restart clears combat state while paused")

	# Play the final stretch with real AI, movement, pickup, and attack input.
	game.restart_journey()
	front.set_physics_process(true)
	behind.set_physics_process(true)
	for shade in game.forest.enemies.slice(2):
		shade.set_physics_process(false)
	prince.position = Vector2(450, 380)
	await _frames(40)
	for i in range(240):
		if game.mode == &"playing":
			break
		await _frames(1)
	prince.position = Vector2(2650, 380)
	prince.velocity = Vector2.ZERO
	await _frames(40)
	var recovering := false
	for i in range(1400):
		if game.mode == &"item_reveal":
			_key(KEY_ENTER, true)
			_key(KEY_ENTER, false)
			await _frames(1)
			continue
		if game.mode != &"playing":
			break
		if front.health <= 0 and behind.health <= 0 and prince.position.x > 3500.0:
			break
		var target: CharacterBody2D = front if front.health > 0 else behind if behind.health > 0 else null
		if target:
			var distance: float = target.position.x - prince.position.x
			if prince.stamina < ForestPrince.ATTACK_STAMINA_COST:
				recovering = true
			elif prince.stamina >= 100.0:
				recovering = false
			Input.action_release("move_left")
			Input.action_release("move_right")
			if prince.velocity.y >= 0.0:
				Input.action_release("jump")
			if recovering:
				# Retreat during recovery; jump across the raised root if needed.
				if absf(distance) < 280.0:
					Input.action_press("move_left" if distance > 0.0 else "move_right")
				if prince.is_on_floor() and absf(distance) < 200.0:
					Input.action_press("jump")
			elif absf(distance) > 65.0 or signf(distance) != prince.facing:
				Input.action_press("move_right" if distance > 0.0 else "move_left")
			if not recovering and absf(distance) < 100.0 and prince.cooldown_left <= 0.0 and prince.stamina >= ForestPrince.ATTACK_STAMINA_COST:
				Input.action_press("attack")
			else:
				Input.action_release("attack")
		else:
			Input.action_release("move_left")
			Input.action_press("move_right")
		await _frames(1)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("attack")
	Input.action_release("jump")
	if front.health > 0 or behind.health > 0:
		print("FIGHT DIAGNOSTICS: mode=%s prince_hp=%s stamina=%s position=%s front_hp=%s behind_hp=%s" % [game.mode, prince.health, prince.stamina, prince.position, front.health, behind.health])
	_check(front.health == 0 and behind.health == 0, "Normal sword input can defeat both active shades")
	_check(game.mode == &"playing" and prince.health > 0 and prince.position.x > 3500.0, "Prince can win both fights and continue beyond the old ending")
	if failures.is_empty():
		print("PASS: All combat checks passed.")
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

func _wait_for_stamina() -> void:
	for i in range(240):
		if prince.stamina >= ForestPrince.ATTACK_STAMINA_COST and prince.cooldown_left <= 0.0:
			return
		await _frames(1)

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _screenshot(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
