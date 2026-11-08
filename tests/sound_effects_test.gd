extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var prince: ForestPrince = game.forest.player
	var sounds = game.sound_effects
	for i in range(8):
		await physics_frame
		await process_frame
	for voice in sounds.voices:
		voice.stop()
	Input.action_press("jump")
	await physics_frame
	await process_frame
	Input.action_release("jump")
	_check(not _playing(sounds, &"jump"), "Jump does not play a sound")
	prince.has_sword = true
	_check(prince.attack(), "Sword attack starts")
	_check(_playing(sounds, &"swing"), "Attack plays its sound")
	prince.take_damage(10, prince.global_position + Vector2(100, 0))
	_check(_playing(sounds, &"swing") and _playing(sounds, &"hurt"), "Attack and damage effects overlap")
	prince.equip_amulet()
	_check(paused and _playing(sounds, &"item"), "Item sound plays through the paused reveal")
	_check(game.music_player.playing, "Background music continues during the reveal")
	paused = false
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: Sound effects respond to gameplay and overlap.")
	quit(0 if failures.is_empty() else 1)

func _playing(sounds: Node, cue: StringName) -> bool:
	for voice in sounds.voices:
		if voice.playing and voice.stream == sounds.SOUNDS[cue]:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures.append(message)
