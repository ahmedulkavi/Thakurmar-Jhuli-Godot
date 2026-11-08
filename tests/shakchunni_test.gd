extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var forest: ForestLevel = game.forest
	var prince: ForestPrince = forest.player
	var arena: Node2D = forest.boss_arena
	var boss: CharacterBody2D = arena.boss
	for enemy in forest.enemies + forest.bats:
		enemy.set_physics_process(false)
	await _frames(5)
	_check(arena.FOG_X > forest.FOUNTAIN_X and not arena.active and not game.boss_panel.visible, "Fog wall follows the fountain; boss is dormant")
	_check(arena.islands.size() >= 6 and boss.health == boss.MAX_HEALTH, "Floating platforms and full-health boss exist")
	prince.position = Vector2(arena.FOG_X - 70, forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	await _frames(6)
	Input.action_press("move_right")
	await _frames(35)
	Input.action_release("move_right")
	_check(prince.position.x < arena.FOG_X - 25 and arena.can_enter(), "Solid fog blocks walking through and offers entry")
	_key(KEY_E)
	await _frames(4)
	_check(arena.active and boss.active and prince.position.x > arena.FOG_X and game.boss_panel.visible, "Interaction crosses gate and starts encounter with boss bar")
	Input.action_press("move_left")
	await _frames(30)
	Input.action_release("move_left")
	_check(prince.position.x > arena.FOG_X + 25, "Fog seals behind the player")
	boss._set_state(&"waiting", 10.0)
	var start_pos: Vector2 = boss.position
	var initial_pose: int = boss.pose_frame
	await _frames(30)
	_check(boss.position.x < start_pos.x - 5.0 and absf(boss.position.y - start_pos.y) > 1.0, "Boss hovers toward the player in both axes")
	_check(boss.art.texture is AtlasTexture and boss.art.texture.atlas == boss.IDLE_SHEET and boss.pose_frame != initial_pose, "Boss plays a living idle animation")
	# Verify the actual one-way islands form a reachable staircase.
	boss.set_physics_process(false)
	for idx in range(arena.islands.size() - 1):
		var island: StaticBody2D = arena.islands[idx]
		var deck := island.get_child(0) as CollisionShape2D
		prince.position = island.position + Vector2(0, deck.position.y - deck.shape.size.y * 0.5 - 1.0)
		prince.velocity = Vector2.ZERO
		await _frames(4)
		Input.action_press("move_right")
		Input.action_press("jump")
		await _frames(30)
		Input.action_release("move_right")
		await _frames(30)
		Input.action_release("jump")
		await _frames(2)
		var target: StaticBody2D = arena.islands[idx + 1]
		var target_deck := target.get_child(0) as CollisionShape2D
		var target_top: float = target.position.y + target_deck.position.y - target_deck.shape.size.y * 0.5
		_check(prince.is_on_floor() and absf(prince.position.y - target_top) < 4.0, "Normal jump reaches floating island %d" % (idx + 1))
	boss.set_physics_process(true)
	# Exercise a real sword swing against her elevated hurtbox.
	prince.has_sword = true
	prince.position = Vector2(arena.BOSS_X - 150, 340)
	prince.velocity = Vector2.ZERO
	prince.facing = 1.0
	boss._set_state(&"waiting", 10.0)
	await _frames(2)
	_check(prince.attack(), "Sword attack can start near boss")
	await _frames(14)
	_check(boss.health == boss.MAX_HEALTH - 1 and game.boss_health.value == boss.health, "Sword hits elevated boss and updates health bar")
	# Test a committed arm attack through the real physics update.
	prince.position = Vector2(7500, forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	prince.invulnerable_left = 0
	boss.arm_target = prince.global_position + Vector2(0, -65)
	boss.arm_hit = false
	boss._set_state(&"strike", 0.3)
	_check(boss.art.texture == boss.ATTACK_TEXTURE and boss.previous_art.visible, "Attack keeps one aligned torso and blends from the idle pose")
	var before: int = prince.health
	await _frames(13)
	_check(prince.health < before and boss.arm_hit, "Extended arm deals damage on contact")
	prince.invulnerable_left = 0.0
	prince.knockback_left = 0.0
	boss.arm_target = prince.global_position + Vector2(250, -65)
	boss.arm_hit = false
	boss._set_state(&"strike", 0.3)
	before = prince.health
	await _frames(20)
	_check(prince.health == before, "A player outside the marked strike can dodge")
	prince.has_sword = true
	prince.set_stance(&"steel")
	prince.cooldown_left = 0.0
	prince.swing_left = 0.0
	prince.stamina = prince.MAX_STAMINA
	boss.arm_target = prince.global_position + Vector2(0, -65)
	boss.arm_hit = false
	boss._set_state(&"strike", 0.3)
	_check(prince.attack(), "Steel opens counter window against boss")
	var boss_before: int = boss.health
	await _frames(13)
	_check(boss.health == boss_before - prince.COUNTER_DAMAGE and prince.health == before and boss.state == &"recover", "Steel counter interrupts the reaching strike")
	prince.set_stance(&"royal")
	prince.god_mode = true
	boss.attack_count = 3
	boss.frenzy_left = 0.0
	boss._set_state(&"recover", 0.01)
	await _frames(3)
	_check(boss.state == &"laugh" and boss.voice.playing and game.boss_phase.text.contains("untouchable"), "Laugh phase plays sound and signals invulnerability")
	var laugh_start_frame: int = boss.pose_frame
	await _frames(28)
	_check(boss.state == &"laugh" and boss.art.texture is AtlasTexture and boss.art.texture.atlas == boss.LAUGH_SHEET and boss.pose_frame > laugh_start_frame, "Laugh plays expressive animation frames")
	var laugh_remaining: float = boss.time_left
	var paused_pose: int = boss.pose_frame
	var paused_position: Vector2 = boss.position
	game.pause_journey()
	await _frames(20)
	_check(is_equal_approx(boss.time_left, laugh_remaining) and boss.pose_frame == paused_pose and boss.position == paused_position, "Pause freezes the laugh and movement")
	game.resume_journey()
	var laugh_health: int = boss.health
	boss.take_damage(100, prince.global_position)
	_check(boss.health == laugh_health, "Boss ignores damage while laughing")
	await _frames(140)
	_check(boss.frenzy_left > 0.0 and boss.state != &"laugh", "Laugh ends in a timed frenzy")
	_check((boss.reaching and boss.art.texture == boss.ATTACK_TEXTURE) or (boss.art.texture is AtlasTexture and boss.art.texture.atlas == boss.IDLE_SHEET), "Boss resumes combat poses after laughing")
	boss._set_state(&"recover", 0.01)
	await _frames(2)
	_check(boss.state == &"windup" and boss.time_left < 0.45, "Frenzy shortens attack windup")
	# A checkpoint retry must reopen entry and restore boss health and phases.
	prince.god_mode = false
	prince.invulnerable_left = 0.0
	forest.checkpoint_active = true
	prince.take_damage(1000, boss.global_position)
	_check(game.mode == &"defeated" and paused, "Death opens retry screen")
	game.restart_journey()
	await _frames(4)
	_check(not arena.active and boss.health == boss.MAX_HEALTH and not game.boss_panel.visible and absf(prince.position.x - forest.FOUNTAIN_X) < 100, "Checkpoint retry resets encounter outside fog")
	prince.position = Vector2(arena.FOG_X - 60, forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	await _frames(5)
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await _frames(2)
	_check(arena.active and boss.active, "Controller RB re-enters after retry")
	boss.take_damage(100, prince.global_position)
	await _frames(105)
	_check(arena.beaten and game.mode == &"complete" and paused, "Defeating boss completes journey")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All Shakchunni checks passed.")
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
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
