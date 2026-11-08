extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var player: AudioStreamPlayer = game.music_player
	var track := player.stream as AudioStreamOggVorbis
	if not player.playing or not track or not track.loop:
		push_error("Background music should start with looping enabled")
		quit(1)
		return
	game.pause_journey()
	game.restart_journey()
	if not player.playing:
		push_error("Background music should continue after restart")
		quit(1)
		return
	player.seek(track.get_length() - 0.2)
	await create_timer(0.7, true).timeout
	if not player.playing or player.get_playback_position() > 2.0:
		push_error("Background music did not wrap back to the start")
		quit(1)
		return
	game.pause_journey()
	if not player.playing or player.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("Background music should continue while the game is paused")
		quit(1)
		return
	game.restart_journey()
	if game.music_player != player or not player.playing:
		push_error("Restart should keep the same music player")
		quit(1)
		return
	print("PASS: Music starts, loops, and continues through pause and restart.")
	track = null
	player = null
	game.queue_free()
	game = null
	await process_frame
	quit(0)
