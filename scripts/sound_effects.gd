extends Node
## A small voice pool lets movement, combat, and pickup sounds overlap.

const SOUNDS := {
	&"jump": preload("res://assets/sfx/jump.wav"),
	&"land": preload("res://assets/sfx/land.wav"),
	&"land_grass": preload("res://assets/sfx/land_grass.wav"),
	&"land_wood": preload("res://assets/sfx/land_wood.wav"),
	&"land_stone": preload("res://assets/sfx/land_stone.wav"),
	&"swing": preload("res://assets/sfx/swing.wav"),
	&"hit": preload("res://assets/sfx/hit.wav"),
	&"hurt": preload("res://assets/sfx/hurt.wav"),
	&"counter": preload("res://assets/sfx/counter.wav"),
	&"item": preload("res://assets/sfx/item.wav"),
	&"essence": preload("res://assets/sfx/essence.wav"),
	&"heal": preload("res://assets/sfx/heal.wav"),
	&"stance": preload("res://assets/sfx/stance.wav"),
}
const LEVELS := {&"jump": -13.0, &"land": -17.0, &"swing": -13.0, &"hit": -12.0,
	&"land_grass": -16.0, &"land_wood": -16.0, &"land_stone": -16.0,
	&"hurt": -11.0, &"counter": -10.0, &"item": -12.0, &"essence": -19.0,
	&"heal": -14.0, &"stance": -17.0}

var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		voices.append(voice)

func play_cue(cue: StringName) -> void:
	if not SOUNDS.has(cue):
		return
	var selected: AudioStreamPlayer
	for voice in voices:
		if not voice.playing:
			selected = voice
			break
	if not selected:
		selected = voices[next_voice]
		next_voice = (next_voice + 1) % voices.size()
	selected.stream = SOUNDS[cue]
	selected.volume_db = LEVELS[cue]
	selected.play()
