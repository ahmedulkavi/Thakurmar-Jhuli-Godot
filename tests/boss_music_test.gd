extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var arena: Node2D = game.forest.boss_arena
	var prince: ForestPrince = game.forest.player
	prince.position = Vector2(arena.FOG_X - 60, game.forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	for i in range(8):
		await physics_frame
		await process_frame
	_check(game.music_player.playing and not game.boss_music_player.playing, "Forest music plays before the fog")
	_check(arena.traverse(), "Entering the fog starts the encounter")
	_check(game.boss_music_player.playing and game.boss_music_active, "Boss music starts on entry")
	var track := game.boss_music_player.stream as AudioStreamOggVorbis
	_check(track != null and track.loop, "Boss music is configured to loop")
	game.boss_music_player.seek(track.get_length() - 0.2)
	await create_timer(1.3, true).timeout
	_check(game.boss_music_player.playing and game.boss_music_player.get_playback_position() < 2.5, "Boss music loops")
	_check(not game.music_player.playing, "Forest music fades out in the arena")
	arena.reset_encounter()
	await create_timer(1.3, true).timeout
	_check(game.music_player.playing and not game.boss_music_player.playing, "Encounter reset restores forest music")
	prince.position = Vector2(arena.FOG_X - 60, game.forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	for i in range(8):
		await physics_frame
		await process_frame
	_check(arena.traverse(), "Boss music can start again on retry")
	arena.boss.take_damage(100, prince.global_position)
	await create_timer(1.3, true).timeout
	_check(game.music_player.playing and not game.boss_music_player.playing, "Defeating Shakchunni restores forest music")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failures += 1
