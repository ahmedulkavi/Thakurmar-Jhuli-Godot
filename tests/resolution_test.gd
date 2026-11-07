extends SceneTree
## --headless --path . --fixed-fps 60 --script res://tests/resolution_test.gd
## Omit --headless and add -- --capture to verify native fullscreen and save images.

var game: Control
var failures: Array[String] = []
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(12)
	if DisplayServer.get_name() != "headless":
		_check(root.mode == Window.MODE_MAXIMIZED, "Game starts maximized to fit the monitor")
	else:
		_check(ProjectSettings.get_setting("display/window/size/mode") == Window.MODE_MAXIMIZED, "Project starts maximized when a display is available")
	root.mode = Window.MODE_WINDOWED
	await _frames(5)
	for resolution in [Vector2i(816, 564), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080), Vector2i(1600, 1200)]:
		root.size = resolution
		await _frames(8)
		_check(root.size == resolution, "Window accepts %s" % resolution)
		_check_render_size("%s" % resolution)
		var bounds := Rect2(Vector2(-1, -1), game.size + Vector2(2, 2))
		_check(bounds.encloses(game.interface.get_global_rect()), "Header, game, and controls fit at %s" % resolution)
		_check(game.world.size_2d_override == Vector2i(1280, 720) and game.forest.camera.zoom == Vector2.ONE, "Resize preserves the gameplay view at %s" % resolution)
		if resolution == Vector2i(2560, 1440):
			await _screenshot("resolution-qhd-windowed")
	_check(is_equal_approx(game.forest.player.position.y, 586.0), "Resizing preserves floor alignment and physics")

	# The UI and render target must adapt even while physics is paused.
	game.pause_journey()
	var paused_position: Vector2 = game.forest.player.position
	root.size = Vector2i(1920, 1080)
	await _frames(8)
	_check_render_size("paused resize")
	_check(paused and game.forest.player.position == paused_position and game.overlay.visible, "Paused resize keeps the game and overlay state")
	_click(game.primary)
	await _frames(4)
	_check(not paused and game.mode == &"playing", "Continue button receives mouse clicks at the resized pixel coordinates")
	if paused:
		game.resume_journey()
	_click(game.pause_button)
	await _frames(4)
	_check(paused and game.mode == &"paused", "Pause button receives mouse clicks after resizing")
	game.resume_journey()

	# Exercise F11 on the real display, including restoration of a maximized window.
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MAXIMIZED
		await _frames(12)
		_key(KEY_F11)
		await _frames(20)
		var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		_check(root.mode == Window.MODE_FULLSCREEN and root.size == screen_size, "F11 uses the monitor's native fullscreen resolution")
		_check(root.get_texture().get_image().get_size() == screen_size, "Fullscreen framebuffer renders all native screen pixels")
		_check_render_size("native fullscreen")
		print("NATIVE FULLSCREEN: %s; FOREST RENDER TARGET: %s" % [root.size, game.world.size])
		await _screenshot("resolution-native-fullscreen")
		game.pause_journey()
		await _frames(2)
		await _screenshot("resolution-native-paused")
		_key(KEY_F11)
		await _frames(20)
		_check(root.mode == Window.MODE_MAXIMIZED and paused, "F11 restores maximized mode while paused")
		_check_render_size("restored maximized")
		game.resume_journey()
	game.restart_journey()
	await _frames(3)
	_check(game.mode == &"playing" and game.forest.player.health == 100 and not game.overlay.visible, "Restart works after resizing and display mode changes")
	if failures.is_empty():
		print("PASS: All adaptive resolution checks passed.")
	else:
		for failure in failures:
			push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check_render_size(description: String) -> void:
	# Godot rounds the expanded logical canvas to whole pixels, so use its
	# actual extent when comparing native pixels (not an ideal aspect ratio).
	var pixel_scale := Vector2(root.size) / root.get_visible_rect().size
	var expected := Vector2i((Vector2(1280, 720) * pixel_scale).round())
	if game.world.size != expected:
		print("DISPLAY DIAGNOSTICS: window=%s logical=%s stretch=%s forest=%s expected=%s" % [root.size, game.size, root.get_stretch_transform(), game.world.size, expected])
	_check(game.world.size == expected, "Forest renders at displayed pixel resolution for " + description)
	if DisplayServer.get_name() != "headless":
		_check(game.world.get_texture().get_size() == Vector2(expected), "Forest GPU texture matches native rendering for " + description)

func _click(button: Button) -> void:
	var logical_center := button.get_global_rect().get_center()
	var pixel_center := root.get_stretch_transform() * logical_center
	var motion := InputEventMouseMotion.new()
	motion.position = pixel_center
	motion.global_position = pixel_center
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pixel_center
		event.global_position = pixel_center
		event.pressed = pressed
		root.push_input(event)

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
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
