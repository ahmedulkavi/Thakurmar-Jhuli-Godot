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
	var arena: Node2D = forest.boss_arena
	var water: Node2D = forest.underwater
	for enemy in forest.enemies + forest.bats + water.enemies:
		enemy.set_physics_process(false)
	await _frames(5)
	var palace_position: Vector2 = water.backdrop.position
	var palace_scale: Vector2 = water.backdrop.scale
	prince.position = Vector2(9800, prince.WATER_SURFACE_FEET)
	water._process(0.0)
	prince.position.y = prince.WATER_FLOOR_FEET
	water._process(0.0)
	_check(water.backdrop.position == palace_position and water.backdrop.scale == palace_scale, "Diving keeps the palace and painted water surface anchored in world space")
	_check(forest.WORLD_WIDTH > 18000.0 and forest.camera.limit_right == int(forest.WORLD_WIDTH) and forest.camera.limit_bottom == 1400, "World and camera extend through the underwater kingdom")
	_check(not arena.exit_collision.disabled and water.get_node("Riverbed") != null and water.get_node("Riverbank") != null, "Riverbank joins the arena behind a sealed passage")
	prince.position = Vector2(9100, forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	_check(prince.position.x < arena.ARENA_END, "Prince cannot bypass an undefeated Shakchunni")
	arena._on_boss_defeated()
	await _frames(3)
	Input.action_press("move_right")
	await _frames(170)
	Input.action_release("move_right")
	_check(arena.exit_collision.disabled and prince.position.x > prince.WATER_START_X and prince.in_water, "Defeating Shakchunni opens a walkable bank into the water")
	Input.action_press("move_left")
	await _frames(300)
	Input.action_release("move_left")
	_check(not prince.in_water and prince.is_on_floor() and prince.position.x < forest.FOREST_FLOOR_END - 80.0, "Holding left carries the prince up the bank and onto the forest floor (x=%.1f)" % prince.position.x)
	prince.position = Vector2(11000, 760)
	prince.velocity = Vector2.ZERO
	await _frames(3)
	var starting_y: float = prince.position.y
	Input.action_press("move_down")
	await _frames(35)
	Input.action_release("move_down")
	_check(prince.position.y > starting_y + 50, "Down swims into the kingdom")
	starting_y = prince.position.y
	Input.action_press("move_up")
	await _frames(35)
	Input.action_release("move_up")
	_check(prince.position.y < starting_y - 12, "Up swims toward the surface")
	prince.set_stance(&"royal")
	prince._update_combat_visuals()
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.ROYAL_SWIM_SHEET, "Royal has its own swim frames")
	prince.set_stance(&"steel")
	prince._update_combat_visuals()
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.STEEL_SWIM_SHEET, "Steel has its own swim frames")
	prince.set_stance(&"hunter")
	prince._update_combat_visuals()
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.HUNTER_SWIM_SHEET, "Hunter has its own swim frames")
	prince.equip_sword()
	prince.set_stance(&"royal")
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.SWORD_SWIM_SHEET, "Armed prince carries the painted sword before attacking")
	var target: CharacterBody2D = water.enemies[0]
	target.position = prince.position + Vector2(80, -62)
	prince.facing = 1.0
	var target_health: int = target.health
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	_check(prince.combat_visual.swim_weapon == &"slash", "The swimming slash draws its blade")
	await _frames(32)
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.SWORD_SWIM_SHEET, "Sword stays in hand after recovery")
	_check(target.health == target_health - 1, "The swimming slash hits its target")
	prince.set_stance(&"hunter")
	prince.magic = prince.MAX_MAGIC
	prince.facing = -1.0
	target.position = prince.position + Vector2(-250, -66)
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	_check(prince.combat_visual.swim_weapon == &"bow" and forest.get_children().any(func(n: Node) -> bool: return n.get_script() == prince.HUNTER_ARROW_SCRIPT and n.underwater and n.direction < 0), "Hunter shows the bow and fires an underwater arrow to the left")
	await _frames(30)
	_check(target.health == target_health - 2, "The swimming arrow hits its target")
	target.reset_enemy()
	var health_before: int = prince.health
	await _frames(600)
	_check(prince.health == health_before and prince.in_water, "Prince breathes underwater without a timer or damage")
	_check(water.enemies.size() >= 6 and water.enemies[0].kind == &"eel" and water.enemies[1].kind == &"sentinel", "Water biome has eel and coral sentinel enemies")
	prince.god_mode = true
	var eel: CharacterBody2D = water.enemies[0]
	eel.set_physics_process(true)
	prince.position = eel.position + Vector2(150, 0)
	prince.velocity = Vector2.ZERO
	await _frames(55)
	_check(eel.state in [&"windup", &"dash", &"recover"], "Eel telegraphs and dashes at a nearby swimmer")
	eel.set_physics_process(false)
	var sentinel: CharacterBody2D = water.enemies[1]
	sentinel.set_physics_process(true)
	prince.position = sentinel.position + Vector2(180, 0)
	prince.velocity = Vector2.ZERO
	await _frames(55)
	_check(water.get_children().any(func(node: Node) -> bool: return node.get_script() == sentinel.WATER_BOLT), "Coral sentinel launches water bolts")
	var charged := false
	for i in range(210):
		await _frames(1)
		if sentinel.state == &"dash":
			charged = true
			break
	_check(charged, "The coral sentinel follows its volley with a charging bite")
	sentinel.set_physics_process(false)
	eel.take_damage(eel.health, prince.position)
	await _frames(3)
	_check(eel.health == 0 and forest.essence_drops.get_child_count() > 0, "Water enemies can be defeated and drop Essence")
	forest.reset_journey()
	await _frames(3)
	_check(water.enemies[0].health == 3 and water.enemies[1].health == 5 and not prince.in_water, "New journey restores water enemies and land movement")
	_check(not water.get_children().any(func(node: Node) -> bool: return node.get_script() == sentinel.WATER_BOLT), "New journey clears water bolts")
	_check(is_equal_approx(water.backdrop.scale.x, water.backdrop.scale.y), "Palace preserves the painting's aspect ratio")
	var naga: CharacterBody2D = water.enemies[7]
	prince.god_mode = false
	prince.equip_sword()
	prince.position = naga.position + Vector2(65, 60)
	naga.set_physics_process(true)
	for i in range(120):
		await _frames(1)
		if prince.held_by == naga:
			break
	_check(prince.held_by == naga, "Naga captures a nearby swimmer after its windup")
	var held_at := prince.position
	Input.action_press("move_right")
	Input.action_press("jump")
	prince.set_stance(&"hunter")
	_check(not prince.attack() and not prince.roll() and prince.stance == &"royal", "A wrap disables combat and stance changes")
	await _frames(100)
	_check(prince.position.distance_to(held_at) < 1 and prince.health <= 90, "Wrap pins the prince through multiple damage ticks")
	await _frames(100)
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(prince.held_by == null and prince.position.x > held_at.x, "Naga releases its hold and movement resumes")
	naga.set_physics_process(false)
	prince.position = Vector2(prince.HALL_APPROACH_X, prince.WATER_SURFACE_FEET + 6.0)
	prince.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for i in range(240):
		await _frames(1)
		if prince.position.x >= prince.DRY_HALL_X:
			break
	_check(prince.position.x >= prince.DRY_HALL_X and absf(prince.position.y - prince.HALL_FLOOR_Y) < 45.0, "A surface swimmer descends to the raised threshold while moving forward")
	await _frames(30)
	_check(not prince.in_water and prince.is_on_floor() and prince.animation.animation == &"run", "Swimmer enters dry hall and runs on foot")
	_check(absf(prince.position.y - prince.HALL_FLOOR_Y) < 1.0, "Dry hall collision supports the prince at the painted tile height")
	_check(forest.PALACE_FOUNTAIN.y == prince.HALL_FLOOR_Y and water.boss.home.y == prince.HALL_FLOOR_Y, "Palace fountain and rival share the raised floor")
	Input.action_release("move_right")
	Input.action_press("move_left")
	for i in range(300):
		await _frames(1)
		if prince.position.x < prince.HALL_APPROACH_X:
			break
	Input.action_release("move_left")
	_check(prince.position.x < prince.HALL_APPROACH_X and prince.in_water, "Walking back through the entrance restores swimming")
	prince.position = forest.PALACE_FOUNTAIN
	await _frames(4)
	_check(forest.try_rest() and forest.checkpoint == forest.PALACE_FOUNTAIN, "Palace fountain sets local checkpoint")
	prince.stop_resting()
	forest.recover_at_fountain()
	_check(prince.position.distance_to(forest.PALACE_FOUNTAIN) < 50 and prince.health == prince.MAX_HEALTH, "Retry returns to palace fountain")
	var rival: CharacterBody2D = water.boss
	game.mode = &"playing"
	paused = false
	prince.position = rival.position + Vector2.LEFT * 75
	prince.god_mode = true
	var moves: Array = []
	var countered := false
	var whip_landed := false
	for i in range(540):
		await _frames(1)
		if rival.state == &"swing" and rival.beat not in moves:
			moves.append(rival.beat)
		if rival.state == &"guard" and not countered:
			var hp: int = rival.health
			rival.take_damage(1, prince.position)
			countered = rival.state == &"riposte" and rival.health == hp
		if rival.state == &"summon":
			prince.position.x = rival.position.x + rival.facing * 270
			prince.god_mode = false
		if rival.state == &"whip" and prince.health < prince.MAX_HEALTH:
			whip_landed = true
			break
	_check(game.boss_title.text == "The Other Prince" and moves.has(0) and moves.has(1), "Named boss performs royal slash and thrust")
	_check(countered and whip_landed, "Copper guard counters and dark urumi hits beyond sword range")
	rival.take_damage(rival.MAX_HEALTH, prince.position)
	_check(forest.completed and game.mode == &"complete", "Defeating the rival completes the journey")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: Underwater kingdom checks passed.")
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
