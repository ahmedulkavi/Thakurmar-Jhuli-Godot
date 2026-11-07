extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/combat_animation_test.gd
## Omit --headless and add -- --capture to save rendered attack poses.

var game: Control
var prince: ForestPrince
var enemy: CharacterBody2D
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
	enemy = game.forest.enemies[0]
	for shade in game.forest.enemies:
		shade.set_physics_process(false)
	for bat in game.forest.bats:
		bat.set_physics_process(false)
	prince.position = Vector2(1320, 586)
	enemy.position = Vector2(1400, 586)
	await _frames(40)
	prince.equip_sword()
	await _frames(2)
	_check(prince.combat_visual.art.visible and not prince.animation.visible, "Armed guard uses one full-body pose with the sword in hand")
	await _screenshot("sword-guard")
	prince.attack()
	await _frames(3)
	_check(prince.attack_kind == &"slash" and prince.combat_visual.pose_frame <= 1, "First attack visibly winds up for an overhead slash")
	_check(enemy.health == 4, "Slash windup cannot deal damage before the blade comes forward")
	await _screenshot("sword-windup")
	await _frames(7)
	_check(enemy.health == 3, "Slash damage lands during the cutting frames")
	_check(prince.combat_visual.pose_frame >= 3 and prince.combat_visual.pose_frame <= 5, "Impact holds a cutting pose instead of a windup pose")
	_check(not prince.combat_visual.impacts.is_empty(), "Sword contact produces an impact spark")
	await _screenshot("sword-slash")
	await _frames(22)
	_check(prince.swing_left <= 0.0 and prince.combat_visual.art.visible, "Slash recovery returns to armed guard")
	enemy.position = prince.position + Vector2(80, 0)
	prince.attack()
	await _frames(3)
	_check(prince.attack_kind == &"thrust" and prince.combat_visual.pose_frame in [8, 9], "Follow-up attack coils into a distinct thrust windup")
	_check(enemy.health == 3, "Thrust windup cannot damage the target")
	await _frames(7)
	_check(enemy.health == 2 and prince.combat_visual.pose_frame in [10, 11, 12], "Thrust extends the body and blade as its damage lands")
	await _screenshot("sword-thrust")

	# A press in late recovery queues exactly one follow-up, even if held.
	for i in range(30):
		if prince.cooldown_left <= 0.12:
			break
		await _frames(1)
	Input.action_press("attack")
	await _frames(1)
	_check(prince.attack_buffer_left > 0.0 and prince.attack_kind == &"thrust", "Late recovery accepts an early follow-up press")
	await _frames(10)
	_check(prince.attack_kind == &"slash" and prince.swing_left > 0.2, "Buffered follow-up starts a slash after thrust recovery")
	await _frames(45)
	_check(prince.swing_left <= 0.0 and prince.cooldown_left <= 0.0, "Holding attack does not repeat the buffered action")
	Input.action_release("attack")
	await _frames(65)
	prince.attack()
	_check(prince.attack_kind == &"slash", "An idle gap resets the chain to its opening slash")
	await _frames(3)
	game.pause_journey()
	var frame: int = prince.combat_visual.pose_frame
	var remaining := prince.swing_left
	await _frames(20)
	_check(prince.combat_visual.pose_frame == frame and is_equal_approx(prince.swing_left, remaining), "Pause freezes both painted pose and attack timing")
	game.resume_journey()
	prince.take_damage(1, prince.position + Vector2(80, 0))
	_check(prince.swing_left == 0.0 and prince.attack_buffer_left == 0.0 and prince.combat_visual.pose_set == &"locomotion" and prince.combat_visual.locomotion_frame >= 14, "Taking damage interrupts attacks and uses an armed recoil pose")

	# Both full-body sequences mirror, including their blade and forward step.
	game.restart_journey()
	prince.position = Vector2(1320, 586)
	await _frames(4)
	prince.equip_sword()
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	await _frames(6)
	var before := prince.position.x
	prince.attack()
	await _frames(12)
	_check(prince.combat_visual.art.flip_h and prince.position.x < before, "Left-facing slash mirrors the body and steps toward the left")
	await _frames(20)
	prince.attack()
	await _frames(10)
	_check(prince.attack_kind == &"thrust" and prince.combat_visual.art.flip_h, "Left-facing follow-up uses mirrored thrust frames")
	await _screenshot("sword-thrust-left")

	# Airborne swordplay follows jump physics without a ground lunge.
	game.restart_journey()
	prince.position = Vector2(1320, 400)
	await _frames(2)
	prince.equip_sword()
	Input.action_press("move_right")
	prince.attack()
	await _frames(10)
	_check(not prince.is_on_floor() and prince.velocity.x > 200.0 and prince.combat_visual.art.visible, "Airborne attacks retain horizontal movement and gravity")
	Input.action_release("move_right")
	game.restart_journey()
	await _frames(3)
	_check(prince.animation.visible and not prince.combat_visual.visible and prince.chain_left == 0.0 and prince.attack_buffer_left == 0.0, "Restart clears painted combat poses, trails, and attack buffering")

	# Carry the painted sword through an entire stride and the jump cycle.
	prince.position = Vector2(1320, 586)
	await _frames(40)
	prince.equip_sword()
	Input.action_press("move_right")
	var seen_run_frames: Dictionary = {}
	var all_armed := true
	for i in range(50):
		await _frames(1)
		var visual: Node2D = prince.combat_visual
		all_armed = all_armed and visual.pose_set == &"locomotion" and visual.art.visible and not prince.animation.visible
		if visual.pose_set == &"locomotion" and visual.locomotion_frame < 8:
			if not seen_run_frames.has(visual.locomotion_frame):
				await _screenshot("armed-run-right-%d" % visual.locomotion_frame)
			seen_run_frames[visual.locomotion_frame] = true
	_check(all_armed and seen_run_frames.size() == 8, "Entire running cycle uses eight painted armed poses without the unarmed body or weapon overlay")
	_check(prince.combat_visual.art.texture.atlas == prince.combat_visual.RUN_SHEET, "Running uses the forward-and-back arm-swing sheet rather than the fixed-guard movement sheet")
	Input.action_release("move_right")
	await _frames(12)
	_check(prince.combat_visual.pose_set == &"combat" and prince.combat_visual.art.visible, "Stopping returns directly from armed running to matching sword guard")
	Input.action_press("jump")
	await _frames(8)
	_check(prince.combat_visual.pose_set == &"locomotion" and prince.combat_visual.locomotion_frame in [8, 9] and not prince.animation.visible, "Jump rise uses an armed pose with the sword painted in hand")
	await _screenshot("armed-jump-rise")
	await _frames(30)
	_check(prince.combat_visual.pose_set == &"locomotion" and prince.combat_visual.locomotion_frame in [10, 11], "Descending keeps the same painted sword in the armed fall poses")
	await _screenshot("armed-jump-fall")
	Input.action_release("jump")
	for i in range(25):
		await _frames(1)
		if prince.is_on_floor():
			break
	_check(prince.combat_visual.pose_set == &"locomotion" and prince.combat_visual.locomotion_frame in [12, 13], "Landing retains the armed sprite before returning to guard")
	await _screenshot("armed-landing")
	await _frames(20)
	Input.action_press("move_left")
	await _frames(15)
	_check(prince.combat_visual.pose_set == &"locomotion" and prince.combat_visual.locomotion_frame < 8 and prince.combat_visual.art.flip_h, "Leftward running mirrors the entire armed sprite and its sword together")
	await _screenshot("armed-run-left")
	game.pause_journey()
	var run_frame: int = prince.combat_visual.locomotion_frame
	var stride: float = prince.combat_visual.stride_distance
	await _frames(20)
	_check(prince.combat_visual.locomotion_frame == run_frame and is_equal_approx(prince.combat_visual.stride_distance, stride), "Pause freezes armed stride animation")
	game.resume_journey()
	await _frames(12)
	prince.attack()
	await _frames(10)
	_check(prince.combat_visual.pose_set == &"combat" and prince.combat_visual.art.visible and not prince.animation.visible, "Attacking after a run switches to full-body combat without a second weapon")
	game.restart_journey()
	await _frames(3)
	_check(prince.animation.visible and not prince.combat_visual.visible and prince.combat_visual.stride_distance == 0.0, "Restart restores unarmed movement and clears the armed stride")
	if failures.is_empty():
		print("PASS: All sword animation checks passed.")
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

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func _screenshot(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
