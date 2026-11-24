extends SceneTree
## Render with -- --preview to inspect idle, swimming, and mirrored attack poses.

const ENEMY = preload("res://scripts/water_enemy.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1200, 720)
	var background := ColorRect.new()
	background.color = Color("102e3c")
	background.size = Vector2(1200, 720)
	root.add_child(background)
	var player := ForestPrince.new()
	var enemies: Array[CharacterBody2D] = []
	for row in range(3):
		var species: StringName = [&"eel", &"sentinel", &"naga"][row]
		for column in range(4):
			var enemy := ENEMY.new()
			enemy.kind = species
			enemy.player = player
			enemy.position = Vector2(150 + column * 300, 140 + row * 220)
			root.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.set_process(false)
			enemies.append(enemy)
			enemy.motion_phase = 0.0
			var phase: float = enemy.motion_phase
			enemy._animate_body(0.25)
			_check(enemy.motion_phase > phase and enemy.swim_blend == 0.0, "%s breathes at rest" % species)
			var idle_step: float = enemy.motion_phase - phase
			enemy.velocity = Vector2(140, 0)
			enemy._animate_body(0.25)
			phase = enemy.motion_phase
			enemy._animate_body(0.25)
			_check(enemy.motion_phase - phase > idle_step and enemy.swim_blend > 0.5, "%s swims with a faster body rhythm" % species)
			enemy.state = &"windup"
			enemy._animate_body(0.25)
			_check(enemy.tension_blend > 0.5, "%s builds anticipation" % species)
			enemy.state = &"dash"
			enemy._animate_body(0.25)
			_check(enemy.burst_blend > 0.5, "%s drives its attack with a stronger beat" % species)
			enemy.reset_enemy()
			_check(enemy.swim_blend == 0.0 and enemy.burst_blend == 0.0 and enemy.tension_blend == 0.0, "%s resets its animation effort" % species)
			# Fixed poses let the two idle columns expose local body deformation.
			enemy.motion_phase = 0.4 if column == 0 else 2.0
			enemy.swim_blend = 1.0 if column >= 2 else 0.0
			enemy.burst_blend = 1.0 if column == 3 else 0.0
			enemy.state = &"dash" if column == 3 else &"patrol"
			enemy.art.flip_h = column == 3
			enemy._animate_body(0.0)
			enemy.art.rotation = 0.0
			enemy.art.position = Vector2.ZERO
			var label := Label.new()
			label.position = Vector2(column * 300 + 18, row * 220 + 20)
			label.text = str(species) + " / " + ["idle A", "idle B", "swimming", "attack (mirrored)"][column]
			root.add_child(label)
	_check(enemies[0].motion_material != enemies[1].motion_material, "Enemies animate independently")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var board := root.get_texture().get_image()
		for row in range(3):
			var first := board.get_region(Rect2i(20, 60 + row * 220, 260, 160))
			var second := board.get_region(Rect2i(320, 60 + row * 220, 260, 160))
			_check(first.get_data() != second.get_data(), "Species %d visibly deforms between idle phases with a fixed sprite transform" % row)
		if "--preview" in OS.get_cmdline_user_args():
			board.save_png("res://artifacts/water-enemy-motion-preview.png")
	for enemy in enemies:
		enemy.free()
	player.free()
	quit(0 if failures == 0 else 1)
