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
	_setup()
	_check(not rival.stance_aura.visible, "Reset starts without a stance aura")
	rival._set_stance(1)
	_check(not rival.stance_aura.visible, "Royal slash to thrust does not trigger a stance aura")
	rival._set_stance(2)
	_check(rival.stance_aura.visible and rival.stance_aura.time_left > 0.0, "Changing to Steel bursts the stance aura")
	rival.stance_aura._process(0.2)
	var aura_remaining: float = rival.stance_aura.time_left
	rival._set_stance(2)
	_check(is_equal_approx(rival.stance_aura.time_left, aura_remaining), "Re-entering the same stance does not restart its aura")
	rival.stance_aura._process(1.0)
	_check(not rival.stance_aura.visible, "Stance aura fades away")
	rival._set_stance(0)
	_check(rival.stance_aura.visible, "Changing back to Royal also bursts the aura")
	rival.reset_boss()
	_check(not rival.stance_aura.visible, "Reset clears an active aura")
	_setup()
	rival.counter_rng.seed = 8128
	var guards := 0
	for i in range(1000):
		rival.state = &"approach"
		if rival._try_reactive_guard(prince.global_position):
			guards += 1
	_check(guards > 640 and guards < 760, "Seeded reactions approximate a 70 percent chance (%d/1000)" % guards)

	_setup()
	_seed_reaction(true)
	_check(prince.attack() and rival.state == &"guard" and rival.visual.steel_equipped, "A real sword swing switches the rival to Copper Steel guard")
	var hp: int = rival.health
	rival.take_damage(1, prince.global_position)
	_check(rival.health == hp and rival.state == &"riposte", "Frontal sword contact is blocked and starts a riposte")
	rival.left = prince.SWING_DURATION - 0.12
	var player_hp := prince.health
	rival._physics_process(0.0)
	_check(prince.health == player_hp - 22, "Reactive riposte can damage the player")

	_setup()
	_seed_reaction(false)
	prince.attack()
	_check(rival.state == &"approach", "A failed chance leaves the rival open")
	rival.take_damage(1, prince.global_position)
	_check(rival.health == rival.MAX_HEALTH - 1, "A failed counter allows normal sword damage")

	_setup()
	_seed_reaction(true)
	prince.position.x -= 500
	prince.attack()
	_check(rival.state == &"approach", "Distant sword swings do not provoke a counter")
	_setup()
	_seed_reaction(true)
	prince.facing = -1
	prince.attack()
	_check(rival.state == &"approach", "Swings facing away do not provoke a counter")
	for committed in [&"riposte", &"whip"]:
		_setup()
		_seed_reaction(true)
		rival.state = committed
		_check(not rival.try_reflect_arrow(prince.global_position), "Committed %s cannot reflect an arrow" % committed)

	_setup()
	rival.state = &"guard"
	rival.facing = -1
	rival.take_damage(1, rival.position + Vector2.RIGHT * 60)
	_check(rival.health == rival.MAX_HEALTH - 1, "Guard is vulnerable to hits from behind")

	# Real raycast travel: both directions must return to and hurt the shooter.
	for side in [-1.0, 1.0]:
		_setup()
		prince.position.x = rival.position.x + side * 250
		prince.facing = -side
		prince.set_stance(&"hunter", false)
		prince.magic = 100
		_seed_reaction(true)
		await _frames(2)
		_check(prince.attack(), "Hunter launches a real arrow")
		await _frames(15)
		var reflected := false
		for child in game.forest.get_children():
			if child.get_script() == prince.HUNTER_ARROW_SCRIPT:
				reflected = child.reflected_by == rival and child.direction == side
		_check(reflected and rival.health == rival.MAX_HEALTH, "Rival reflects the incoming arrow without damage")
		await _frames(25)
		_check(prince.health == prince.MAX_HEALTH - 14, "Reflected arrow hits its shooter from either side")

	_setup()
	prince.position.x = rival.position.x - 250
	prince.set_stance(&"hunter", false)
	prince.magic = 100
	_seed_reaction(false)
	await _frames(2)
	prince.attack()
	await _frames(35)
	_check(rival.health == rival.MAX_HEALTH - 1 and prince.health == prince.MAX_HEALTH, "Failed arrow counter deals ordinary damage and does not reflect")

	_setup()
	rival.active = false
	_seed_reaction(true)
	_check(not rival.try_reflect_arrow(prince.global_position), "Inactive rival cannot counter")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: Other Prince reactive counter and arrow reflection checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _setup() -> void:
	rival.reset_boss()
	rival.position = Vector2(18000, 1100)
	rival.active = true
	rival.collision_layer = 4
	prince.position = rival.position + Vector2.LEFT * 80
	prince.velocity = Vector2.ZERO
	prince.equip_sword()
	prince.set_stance(&"royal", false)
	prince.facing = 1
	prince.health = prince.MAX_HEALTH
	prince.stamina = prince.MAX_STAMINA
	prince.invulnerable_left = 0
	prince.counter_window_left = 0
	prince.cooldown_left = 0
	prince.swing_left = 0
	prince.god_mode = false

func _seed_reaction(success: bool) -> void:
	var rng := RandomNumberGenerator.new()
	for value in range(1, 100):
		rng.seed = value
		if (rng.randf() < rival.COUNTER_CHANCE) == success:
			rival.counter_rng.seed = value
			return
	push_error("Could not seed counter reaction")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
