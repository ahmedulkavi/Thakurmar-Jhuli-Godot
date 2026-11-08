extends SceneTree

var cues: Array[StringName] = []
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var forest: ForestLevel = game.forest
	var prince: ForestPrince = forest.player
	prince.sound_requested.connect(func(cue: StringName): cues.append(cue))
	for enemy in forest.enemies + forest.bats:
		enemy.set_physics_process(false)
	await _drop(prince, Vector2(170, 470))
	_check(&"land_grass", "Grassy forest floor")
	await _drop(prince, Vector2(1980, 435))
	_check(&"land_wood", "Wooden branch")
	var island: StaticBody2D = forest.boss_arena.islands[0]
	var shape: CollisionShape2D = island.get_child(0)
	var deck_top: float = island.position.y + shape.position.y - shape.shape.size.y * 0.5
	await _drop(prince, Vector2(island.position.x, deck_top - 70))
	_check(&"land_grass", "Mossy boss island")
	var stone := StaticBody2D.new()
	stone.position = Vector2(6000, 200)
	stone.collision_layer = 8
	stone.add_to_group("landing_stone")
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(180, 20)
	collider.shape = rect
	stone.add_child(collider)
	forest.add_child(stone)
	await _drop(prince, Vector2(6000, 120))
	_check(&"land_stone", "Stone platform")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _drop(prince: ForestPrince, at: Vector2) -> void:
	cues.clear()
	prince.position = at
	prince.velocity = Vector2.ZERO
	for i in range(35):
		await physics_frame
		await process_frame

func _check(expected: StringName, label: String) -> void:
	if expected not in cues:
		failures += 1
		push_error("%s did not play %s: %s" % [label, expected, cues])
	else:
		print("PASS: %s plays %s" % [label, expected])
