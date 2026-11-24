extends SceneTree
## Run with -- --preview to save a rendered pose board in artifacts/.

const BOSS = preload("res://scripts/shakchunni.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _run() -> void:
	var boss := BOSS.new()
	root.add_child(boss)
	boss.set_physics_process(false)
	boss.active = true
	boss.arm_target = Vector2(-620, -240)
	boss._set_state(&"windup", 0.85)
	boss.time_left = 0.0
	boss._update_pose()
	var hand := boss._arm_endpoint()
	boss._set_state(&"strike", 0.34)
	_check(hand.distance_to(boss._arm_endpoint()) < 0.01, "Windup flows into strike without a hand teleport")
	boss.time_left = 0.34 * 0.55
	boss._update_pose()
	hand = boss._arm_endpoint()
	boss.stun_from_block()
	_check(boss.reaching and hand.distance_to(boss._arm_endpoint()) < 0.01, "Block retracts the visible arm from its actual interrupted position")
	boss.time_left = 0.0
	_check(boss._arm_endpoint().distance_to(boss._rest_hand()) < 0.01, "Block recovery reaches the resting hand without a snap")
	for duration in [0.24, 0.34]:
		boss._set_state(&"strike", duration)
		boss.time_left = duration * 0.2
		_check(boss.to_global(boss._arm_endpoint()).distance_to(boss.arm_target) < 0.01, "Normal/frenzy reach lands on the locked target")
		var world_hand := boss.to_global(boss._arm_endpoint())
		boss.position += Vector2(17, -8)
		_check(boss.to_global(boss._arm_endpoint()).distance_to(world_hand) < 0.01, "Hover does not drag the hand off the committed target")
		boss._set_state(&"recover", 0.3 if duration < 0.3 else 0.9)
		_check(boss.to_global(boss._arm_endpoint()).distance_to(world_hand) < 0.01, "Recovery starts at the exact impact position")
	boss._set_state(&"windup", 0.85)
	boss.art.rotation = 0.12
	boss.art.position += Vector2(12, 9)
	_check(boss._shoulder_position().distance_to(boss.art.transform * Vector2(-107, -389)) < 0.01, "Shoulder socket follows torso translation, rotation, and breathing scale")
	boss.take_damage(100, Vector2.ZERO)
	_check(boss.death_arm and boss.art.texture == boss.ATTACK_TEXTURE, "Death preserves the current reaching pose through collapse")
	boss.reset_boss()
	_check(not boss.death_arm and not boss.reaching and boss.body_shift == Vector2.ZERO, "Retry clears all motion and collapse state")
	boss.queue_free()
	await process_frame
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
	quit(0 if failures == 0 else 1)

func _preview() -> void:
	root.size = Vector2i(1600, 1000)
	var backdrop := ColorRect.new()
	backdrop.color = Color("18202b")
	backdrop.size = Vector2(1600, 1000)
	root.add_child(backdrop)
	var names := ["Idle / breath", "Anticipation", "Elongating reach", "Contact / fixed-size hand", "Interrupted recovery", "Laugh"]
	for i in range(6):
		var origin := Vector2((i % 3) * 533, (i / 3) * 500)
		var label := Label.new()
		label.text = names[i]
		label.position = origin + Vector2(20, 15)
		root.add_child(label)
		var boss := BOSS.new()
		boss.position = origin + Vector2(365, 440)
		boss.scale = Vector2.ONE * 0.65
		root.add_child(boss)
		boss.set_physics_process(false)
		boss.active = true
		boss.clock = 0.65
		boss.arm_target = boss.to_global(Vector2(-440, -280))
		boss._set_state(&"windup", 0.85)
		boss.time_left = 0.0
		if i == 0:
			boss._set_state(&"waiting", 1.0)
		elif i >= 2 and i <= 4:
			boss._set_state(&"strike", 0.34)
			boss.time_left = 0.19 if i == 2 else 0.03
			if i == 4:
				boss.stun_from_block()
				boss.time_left = 0.24
		elif i == 5:
			boss._set_state(&"laugh", boss.LAUGH_TIME)
			boss.time_left = 1.0
		boss.pose_blend = 0.0
		boss._update_body(0.1)
		boss._update_pose()
		boss.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/shakchunni-motion-preview.png")
