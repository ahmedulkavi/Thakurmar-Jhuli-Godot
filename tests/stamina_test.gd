extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/stamina_test.gd
## Omit --headless and add -- --capture to save the full and exhausted HUD.

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
	for enemy in game.forest.enemies:
		enemy.set_physics_process(false)
	await _frames(5)
	_check(prince.stamina == 100.0 and game.stamina_bar.value == 100.0, "Stamina and its HUD start full")
	_check(game.stamina_bar.position.y > game.health_bar.position.y + game.health_bar.size.y, "Stamina bar sits below the red health bar")
	_check(game.health_bar.size == Vector2(190, 10) and game.stamina_bar.size == Vector2(190, 10) and not game.magic_bar.visible and game.combat_panel.size.y == 41.0, "Compact HUD initially shows only health and stamina")
	var fill: StyleBoxFlat = game.stamina_bar.get_theme_stylebox("fill")
	_check(fill.bg_color.g > fill.bg_color.r and fill.bg_color.g > fill.bg_color.b, "Stamina bar is green")
	_check(not prince.attack() and prince.stamina == 100.0 and prince.stamina_regen_left == 0.0, "Unarmed attack attempts spend no stamina or regeneration delay")
	prince.equip_sword()
	await _screenshot("stamina-full")
	_check(prince.attack() and prince.stamina == 75.0 and game.stamina_bar.value == 75.0, "Starting a sword attack spends 25 stamina and updates the HUD immediately")
	var delay := prince.stamina_regen_left
	_check(not prince.attack() and prince.stamina == 75.0 and prince.stamina_regen_left == delay, "Cooldown rejection cannot charge stamina twice or restart regeneration")
	await _frames(30)
	_check(prince.stamina == 75.0 and prince.swing_left <= 0.0, "Stamina stays spent during the short delay after attacking")
	await _frames(10)
	_check(prince.stamina > 75.0 and prince.stamina < 80.0, "Normal regeneration begins shortly after the shortened delay")

	# A follow-up only spends its cost when the next attack actually starts.
	_reset_armed()
	prince.attack()
	await _frames(20)
	_key(KEY_J, true)
	await _frames(1)
	_check(prince.attack_buffer_left > 0.0 and prince.stamina == 75.0, "Queuing a follow-up does not spend stamina early")
	await _frames(10)
	_key(KEY_J, false)
	_check(prince.attack_kind == &"thrust" and prince.stamina == 50.0, "Buffered thrust spends its own stamina exactly once on execution")
	await _frames(28)
	_check(prince.stamina == 50.0, "Finishing the queued animation adds no extra stamina charge")

	# Four full-cost attacks exhaust the pool. Fresh exhausted presses penalize
	# recovery, while a held button neither repeats nor queues an attack.
	_reset_armed()
	var all_attacks_started := true
	for i in range(4):
		all_attacks_started = prince.attack() and all_attacks_started
		await _frames(27)
	_check(all_attacks_started and prince.stamina == 0.0, "Four rapid attacks use the full stamina pool without going negative")
	_check(prince.stamina_regen_left <= ForestPrince.STAMINA_REGEN_DELAY, "Spending exactly 25 on the last attack keeps the normal recovery delay")
	_check(game.stamina_bar.value == 0.0, "Exhausted stamina bar is empty")
	await _screenshot("stamina-exhausted")
	delay = prince.stamina_regen_left
	_key(KEY_J, true)
	await _frames(1)
	_check(prince.swing_left == 0.0 and prince.attack_buffer_left == 0.0 and prince.stamina == 0.0, "Exhausted attack input starts no swing and leaves no queued follow-up")
	_check(prince.stamina_regen_left > delay and prince.stamina_regen_left > 0.95, "Exhausted input restarts the longer 1-second regeneration delay")
	var start_x := prince.position.x
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(12)
	_check(prince.position.x > start_x + 20.0 and prince.position.y < 580.0 and prince.stamina == 0.0, "Running and jumping remain available with zero stamina")
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(150)
	_check(prince.stamina > 35.0 and prince.stamina < 50.0 and prince.swing_left == 0.0, "Stamina regenerates after the delay, and holding rejected attack input cannot auto-attack")
	_key(KEY_J, false)
	_check(is_equal_approx(game.stamina_bar.value, prince.stamina), "HUD follows regenerating stamina")
	var before := prince.stamina
	await _frames(30)
	_check(absf(prince.stamina - before - 12.5) < 0.5, "Regeneration restores 25 stamina per second")
	before = prince.stamina
	_check(prince.attack() and is_equal_approx(prince.stamina, before - 25.0), "Recovered stamina allows another attack at the normal cost")
	await _frames(400)
	_check(prince.stamina == 100.0 and game.stamina_bar.value == 100.0, "Regeneration stops exactly at full stamina")

	# A final strike can overdraw a partially recovered bar, once. Queuing it
	# does not apply the penalty until that swing starts.
	prince._set_stamina(30.0)
	prince.attack()
	await _frames(20)
	delay = prince.stamina_regen_left
	_key(KEY_J, true)
	await _frames(1)
	_key(KEY_J, false)
	_check(prince.attack_buffer_left > 0.0 and prince.stamina == 5.0 and prince.stamina_regen_left < delay, "Low-stamina follow-up queues without charging or penalizing early")
	await _frames(10)
	_check(prince.attack_kind == &"thrust" and prince.stamina == 0.0 and prince.stamina_regen_left > 0.9, "A strike below 25 empties stamina and applies the exhaustion delay when executed")
	_check(game.stamina_bar.value == 0.0, "Overdraw immediately empties the stamina bar")
	await _frames(40)
	_check(prince.stamina == 0.0, "Overdraw blocks regeneration beyond the normal recovery delay")
	_check(not prince.attack() and prince.stamina_regen_left == 1.0, "A fresh zero-stamina attempt refreshes the exhaustion penalty")
	await _frames(40)
	_check(prince.stamina == 0.0, "Repeated exhausted input postpones the next regeneration")
	await _frames(30)
	_check(prince.stamina > 0.0 and prince.stamina < 25.0 and is_equal_approx(game.stamina_bar.value, prince.stamina), "The bar shows partial recovery below the full attack cost")
	_check(prince.attack() and prince.stamina == 0.0 and prince.stamina_regen_left == 1.0, "Partially recovered stamina can be overdrawn without going negative")
	await _frames(400)

	# Pause freezes both the pool and the delay, then recovery resumes normally.
	prince.attack()
	await _frames(10)
	game.pause_journey()
	before = prince.stamina
	delay = prince.stamina_regen_left
	await _frames(100)
	_check(prince.stamina == before and prince.stamina_regen_left == delay and game.stamina_bar.value == before, "Pause freezes stamina, regeneration delay, and HUD value")
	_check(not prince.attack() and prince.stamina == before, "Paused input spends no stamina")
	game.resume_journey()
	await _frames(80)
	_check(prince.stamina > before, "Stamina regeneration resumes after unpausing")

	# An attack already performed stays paid for if interrupted.
	_reset_armed()
	prince.attack()
	prince.take_damage(20, prince.position + Vector2(60, 0))
	_check(prince.swing_left == 0.0 and prince.stamina == 75.0, "Damage interrupts an attack without refunding its stamina")
	await _frames(65)
	prince.take_damage(1000, prince.position + Vector2(60, 0))
	before = prince.stamina
	await _frames(120)
	_check(game.mode == &"defeated" and prince.stamina == before and game.stamina_bar.value == before, "Defeat freezes the remaining stamina")
	game.primary.pressed.emit()
	await _frames(3)
	_check(prince.stamina == 100.0 and prince.stamina_regen_left == 0.0 and game.stamina_bar.value == 100.0, "Try Again restores full stamina and clears the recovery delay")
	prince.equip_sword()
	prince.attack()
	game.complete_journey()
	game.primary.pressed.emit()
	await _frames(3)
	_check(game.mode == &"playing" and prince.stamina == 100.0, "Walking again after completion restores stamina")
	prince.equip_sword()
	prince.attack()
	game.pause_journey()
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(3)
	_check(not paused and prince.stamina == 100.0 and prince.stamina_regen_left == 0.0, "Keyboard restart restores stamina while paused")
	if failures.is_empty():
		print("PASS: All stamina checks passed.")
	else:
		for failure in failures:
			push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _reset_armed() -> void:
	game.restart_journey()
	prince.equip_sword()

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

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
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
