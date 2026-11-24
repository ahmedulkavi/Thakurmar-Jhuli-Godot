extends Control
## The interface keeps processing while Godot pauses the forest subtree.

const GOLD := Color("d8be81")
const INK := Color("192921")
const PAPER := Color("f0eddb")
const MUTED := Color("93b3a2")
const INTERFACE_SIZE := Vector2(1360, 940)
const SWORD_REVEAL_VISUAL = preload("res://scripts/sword_visual.gd")
const ESSENCE_COIN = preload("res://scenes/essence_coin.tres")
const ROYAL_STANCE_ICON = preload("res://assets/royal-stance.png")
const STEEL_STANCE_ICON = preload("res://assets/steel-stance.png")
const HUNTER_STANCE_ICON = preload("res://assets/hunter-stance.png")
const SHAKCHUNNI_ESSENCE_ICON = preload("res://assets/essence-of-shakchunni.png")
const AMULET_TEXTURE = preload("res://assets/healing-amulet.png")
const BLOOD_AMULET_TEXTURE = preload("res://assets/blood-amulet.png")
const BLOOD_BLADE_ICON = preload("res://assets/blood-blade-icon.png")
const FOREST_MUSIC = preload("res://assets/forest-music.ogg")
const BOSS_MUSIC = preload("res://assets/shakchunni-music-louder.ogg")
const FOREST_MUSIC_ENABLED := true
const SOUND_EFFECTS = preload("res://scripts/sound_effects.gd")

@onready var interface: Control = $Interface
@onready var forest: ForestLevel = $Interface/GameFrame/ViewportContainer/World/Forest
@onready var frame: Control = $Interface/GameFrame
@onready var world_image: TextureRect = $Interface/GameFrame/ViewportContainer
@onready var world: SubViewport = $Interface/GameFrame/ViewportContainer/World
var mode: StringName = &"playing"
var character_menu: Control
var menu_resume: Button
var menu_stats: Dictionary = {}
var menu_items: Dictionary = {}
var menu_visible_items: Array[Button] = []
var menu_item_title: Label
var menu_item_description: Label
var menu_stance_slots: Dictionary = {}
var overlay: Control
var victory_screen: Control
var victory_tween: Tween
var kicker: Label
var heading: Label
var copy: Label
var hint: Label
var primary: Button
var serif: SystemFont
var italic: SystemFont
var sans: SystemFont
var pause_button: Button
var combat_panel: Panel
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var magic_bar: ProgressBar
var boss_title: Label
var boss_panel: Control
var boss_health: ProgressBar
var boss_phase: Label
var essence_count: Label
var god_mode_indicator: Label
var stance_icon: TextureRect
var stance_tween: Tween
var amulet_reveal: Control
var reveal_shade: ColorRect
var reveal_halo: Panel
var reveal_art: TextureRect
var reveal_sword: Node2D
var reveal_title: Label
var reveal_copy: Label
var reveal_sparks: Array[Label] = []
var reveal_tween: Tween
var reveal_returns_to_merchant := false
var skill_tree: Control
var skill_buttons: Array[Button] = []
var skill_costs: Array[Label] = []
var skill_coins: Array[TextureRect] = []
var skill_back: Button
var skill_item_requirement: Label
var skill_amulet_icon: TextureRect
var skill_description: Label
var skill_title: Label
var skill_selected := 0
var rest_menu: Control
var rest_buttons: Array[Button] = []
var rest_message: Label
var merchant: Control
var merchant_buy: Button
var merchant_healing: Button
var merchant_hunter: Button
var merchant_status: Label
var merchant_close: Button
var windowed_mode: Window.Mode = Window.MODE_MAXIMIZED
var music_player: AudioStreamPlayer
var boss_music_player: AudioStreamPlayer
var boss_music_active := false
var music_tween: Tween
var sound_effects: Node
var debug_select_held := false
var debug_select_toggled_god_mode := false
var debug_teleport_used := false

func _ready() -> void:
	_start_music()
	sound_effects = SOUND_EFFECTS.new()
	sound_effects.name = "SoundEffects"
	add_child(sound_effects)
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	italic = SystemFont.new()
	italic.font_names = serif.font_names
	italic.font_italic = true
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans"])
	var ui_theme := Theme.new()
	ui_theme.default_font = sans
	ui_theme.default_font_size = 14
	theme = ui_theme
	_build_chrome()
	_build_overlay()
	_build_character_menu()
	_build_victory_screen()
	_build_amulet_reveal()
	_build_rest_menu()
	_build_skill_tree()
	_build_merchant()
	_build_boss_hud()
	forest.journey_complete.connect(complete_journey)
	forest.player.health_changed.connect(_update_health)
	forest.player.stamina_changed.connect(_update_stamina)
	forest.player.magic_changed.connect(_update_magic)
	forest.player.stance_changed.connect(_update_stance)
	forest.player.sound_requested.connect(_play_sound)
	forest.player.sword_equipped.connect(_on_sword_equipped)
	forest.player.amulet_equipped.connect(_on_amulet_equipped)
	forest.player.blood_amulet_collected.connect(_on_blood_amulet_collected)
	forest.player.died.connect(_on_player_died)
	forest.player.resting_started.connect(_open_rest_menu)
	var rival: CharacterBody2D = forest.underwater.boss
	rival.started.connect(func() -> void:
		boss_title.text = "The Other Prince"
		_update_boss_health(rival.health, rival.MAX_HEALTH)
		_set_boss_music(true)
		boss_panel.show())
	rival.health_changed.connect(_update_boss_health)
	rival.stance_changed.connect(func(title: String) -> void: boss_phase.text = title)
	rival.ended.connect(_on_boss_reset)
	forest.boss_arena.encounter_started.connect(_on_boss_started)
	forest.boss_arena.encounter_reset.connect(_on_boss_reset)
	forest.boss_arena.boss.health_changed.connect(_update_boss_health)
	forest.boss_arena.boss.phase_changed.connect(_update_boss_phase)
	forest.boss_arena.boss.defeated.connect(_on_boss_music_end)
	forest.essence_changed.connect(_update_essence)
	forest.essence_discovered.connect(_on_essence_discovered)
	forest.essence_collected.connect(_on_essence_collected)
	forest.shakchunni_essence_collected.connect(_on_shakchunni_essence_collected)
	_update_health(forest.player.health, ForestPrince.MAX_HEALTH)
	_update_stamina(forest.player.stamina, ForestPrince.MAX_STAMINA)
	_update_magic(forest.player.magic, ForestPrince.MAX_MAGIC)
	_update_essence(forest.essence)
	world_image.texture = world.get_texture()
	get_viewport().size_changed.connect(_queue_display_resize)
	resized.connect(_queue_display_resize)
	_resize_display()

func _play_sound(cue: StringName) -> void:
	sound_effects.call("play_cue", cue)

func _start_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "ForestMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var track := FOREST_MUSIC.duplicate() as AudioStreamOggVorbis
	track.loop = true
	music_player.stream = track
	music_player.volume_db = -10.0
	add_child(music_player)
	boss_music_player = AudioStreamPlayer.new()
	boss_music_player.name = "ShakchunniMusic"
	boss_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var boss_track := BOSS_MUSIC.duplicate() as AudioStreamOggVorbis
	boss_track.loop = true
	boss_music_player.stream = boss_track
	boss_music_player.volume_db = -45.0
	add_child(boss_music_player)
	if FOREST_MUSIC_ENABLED:
		music_player.play()

func _set_boss_music(enabled: bool) -> void:
	if not FOREST_MUSIC_ENABLED or boss_music_active == enabled:
		return
	boss_music_active = enabled
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	var incoming := boss_music_player if enabled else music_player
	var outgoing := music_player if enabled else boss_music_player
	if not incoming.playing:
		incoming.volume_db = -45.0
		incoming.play()
	music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_tween.set_parallel(true)
	music_tween.tween_property(incoming, "volume_db", -10.0 if not enabled else -8.0, 1.0)
	music_tween.tween_property(outgoing, "volume_db", -45.0, 1.0)
	music_tween.chain().tween_callback(outgoing.stop)

func _on_boss_music_end() -> void:
	_set_boss_music(false)
	boss_panel.hide()

func _queue_display_resize() -> void:
	_resize_display.call_deferred()

func _resize_display() -> void:
	# Center the readable UI at any aspect ratio; the backdrop fills the window.
	interface.position = (size - INTERFACE_SIZE) * 0.5
	# Preserve game coordinates while rendering every displayed pixel natively.
	var to_pixels := get_viewport().get_stretch_transform() * frame.get_global_transform_with_canvas()
	var pixel_scale := to_pixels.get_scale().abs()
	var pixels := Vector2i((frame.size * pixel_scale).round()).max(Vector2i.ONE)
	if world.size != pixels:
		world.size = pixels

func toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window.mode = windowed_mode
	else:
		windowed_mode = window.mode
		window.mode = Window.MODE_FULLSCREEN

func _input(event: InputEvent) -> void:
	if event.is_action_released("god_mode"):
		debug_select_held = false
		debug_select_toggled_god_mode = false
		debug_teleport_used = false
	if mode == &"playing" and not forest.player.is_resting and not event.is_echo():
		if event.is_action_pressed("god_mode"):
			debug_select_held = true
			if Input.is_action_pressed("move_down"):
				debug_teleport_used = true
				_debug_teleport_before_boss()
				get_viewport().set_input_as_handled()
				return
			debug_select_toggled_god_mode = true
		elif event.is_action_pressed("move_down") and debug_select_held and not debug_teleport_used:
			if debug_select_toggled_god_mode:
				_toggle_god_mode()
				debug_select_toggled_god_mode = false
			debug_teleport_used = true
			_debug_teleport_before_boss()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("god_mode") and not event.is_echo():
		_toggle_god_mode()
		get_viewport().set_input_as_handled()
		return
	if mode == &"paused" and not event.is_echo():
		var left := event.is_action_pressed("move_left") or event.is_action_pressed("stance_royal")
		var right := event.is_action_pressed("move_right") or event.is_action_pressed("stance_steel")
		var up := event.is_action_pressed("move_up")
		var down := event.is_action_pressed("move_down")
		if left or right or up or down:
			_navigate_inventory(left, right, up, down)
			get_viewport().set_input_as_handled()
			return
	if mode == &"skill_tree":
		if event.is_action_pressed("pause") and not event.is_echo():
			_close_skill_tree()
			get_viewport().set_input_as_handled()
		elif (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")) and not event.is_echo():
			var step := -1 if event.is_action_pressed("move_up") else 1
			var target := skill_selected if skill_back.has_focus() else clampi(skill_selected + step, 0, skill_buttons.size() - 1)
			skill_buttons[target].grab_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right") and not event.is_echo():
			skill_back.grab_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left") and not event.is_echo():
			skill_buttons[skill_selected].grab_focus()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
			if skill_back.has_focus():
				_close_skill_tree()
			else:
				_purchase_selected_skill()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			_close_skill_tree()
			get_viewport().set_input_as_handled()
		return
	if mode == &"merchant":
		if event.is_action_pressed("pause") and not event.is_echo():
			_close_merchant()
			get_viewport().set_input_as_handled()
		elif (event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down")) and not event.is_echo():
			if event.is_action_pressed("move_down"):
				merchant_close.grab_focus()
			elif event.is_action_pressed("move_left") and not merchant_buy.disabled:
				merchant_buy.grab_focus()
			elif event.is_action_pressed("move_right"):
				if merchant_healing.has_focus() and not merchant_hunter.disabled:
					merchant_hunter.grab_focus()
				elif not merchant_healing.disabled:
					merchant_healing.grab_focus()
				elif not merchant_hunter.disabled:
					merchant_hunter.grab_focus()
			elif event.is_action_pressed("move_up"):
				_focus_merchant_item()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
			if merchant_buy.has_focus() and not merchant_buy.disabled:
				_buy_steel_stance()
			elif merchant_healing.has_focus() and not merchant_healing.disabled:
				_buy_healing_amulet()
			elif merchant_hunter.has_focus() and not merchant_hunter.disabled:
				_buy_hunter_stance()
			elif merchant_close.has_focus():
				_close_merchant()
			get_viewport().set_input_as_handled()
		return
	if mode == &"item_reveal":
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			if reveal_tween and reveal_tween.is_valid():
				reveal_tween.kill()
			_release_actions()
			_finish_item_reveal()
		return
	if mode == &"resting":
		if event.is_action_pressed("pause") and not event.is_echo():
			_leave_rest()
			get_viewport().set_input_as_handled()
		elif (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")) and not event.is_echo():
			var selected := 0
			for i in range(rest_buttons.size()):
				if rest_buttons[i].has_focus():
					selected = i
			var step := -1 if event.is_action_pressed("move_up") else 1
			rest_buttons[posmod(selected + step, rest_buttons.size())].grab_focus()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
			for button in rest_buttons:
				if button.has_focus():
					button.pressed.emit()
					break
			get_viewport().set_input_as_handled()
		return
	if mode == &"playing" and not forest.player.is_resting and not event.is_echo():
		if event.is_action_pressed("stance_royal"):
			forest.player.set_stance(&"royal")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("stance_steel"):
			if forest.has_steel_stance:
				forest.player.set_stance(&"steel")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("stance_hunter"):
			if forest.has_hunter_stance:
				forest.player.set_stance(&"hunter")
			get_viewport().set_input_as_handled()
			return
	if mode == &"playing" and event.is_action_pressed("interact") and not event.is_echo():
		if forest.try_rest() or forest.boss_arena.traverse() or forest.underwater.traverse():
			get_viewport().set_input_as_handled()
			_release_actions()
		return
	if event.is_action_pressed("restart"):
		restart_journey()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if mode == &"playing":
			pause_journey()
		elif mode == &"paused":
			resume_journey()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _toggle_god_mode() -> void:
	forest.player.god_mode = not forest.player.god_mode
	god_mode_indicator.visible = forest.player.god_mode
	_update_essence(forest.essence)
	if mode == &"paused":
		_refresh_character_menu()
	if mode == &"skill_tree":
		_refresh_skill_tree()
	if mode == &"merchant":
		_refresh_merchant()
		_focus_merchant_item()

func _debug_teleport_before_boss() -> void:
	var prince := forest.player
	var underwater := prince.in_water
	if prince.is_climbing:
		prince._stop_climbing()
	prince.held_by = null
	if underwater:
		prince.position = Vector2(forest.underwater.boss.ENTRY_X - 60.0, prince.HALL_FLOOR_Y)
		prince.in_water = false
		prince.floor_snap_length = 6.0
	else:
		prince.position = Vector2(forest.boss_arena.FOG_X - 60.0, forest.GROUND_Y)
	prince.velocity = Vector2.ZERO
	forest.camera.position = Vector2(prince.position.x + 220.0, prince.HALL_FLOOR_Y - 275.0 if underwater else 360.0)
	forest.camera.reset_smoothing()

func pause_journey() -> void:
	if mode != &"playing":
		return
	mode = &"paused"
	get_tree().paused = true
	pause_button.disabled = true
	_release_actions()
	_refresh_character_menu()
	character_menu.show()
	if menu_visible_items.is_empty():
		menu_resume.grab_focus()
	else:
		menu_visible_items[0].grab_focus()

func complete_journey() -> void:
	mode = &"complete"
	get_tree().paused = true
	pause_button.disabled = true
	_release_actions()
	victory_screen.modulate.a = 0.0
	victory_screen.show()
	victory_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	victory_tween.tween_property(victory_screen, "modulate:a", 1.0, 0.8)
	victory_screen.get_node("Restart").grab_focus()

func _on_player_died() -> void:
	mode = &"defeated"
	kicker.text = "T H E   L I G H T   S T I L L   W A I T S"
	heading.text = "The prince has fallen"
	copy.text = "Claim the blade. Watch for the shades' glow."
	primary.text = "TRY AGAIN     →"
	hint.text = "Press R to restart"
	_show_overlay()

func _update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_bar.add_theme_stylebox_override("fill", _box(Color("f16b62") if current <= 30 else Color("c94b4b"), Color.TRANSPARENT, 3))

func _update_stamina(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func _update_magic(current: float, maximum: float) -> void:
	magic_bar.max_value = maximum
	magic_bar.value = current
	magic_bar.visible = forest.player.has_amulet or forest.player.stance == &"hunter"
	combat_panel.size.y = 58.0 if forest.player.has_amulet or forest.player.stance == &"hunter" else 41.0
	stance_icon.position.y = combat_panel.position.y + combat_panel.size.y + 5.0

func _update_stance(stance: StringName) -> void:
	stance_icon.texture = HUNTER_STANCE_ICON if stance == &"hunter" else STEEL_STANCE_ICON if stance == &"steel" else ROYAL_STANCE_ICON
	stance_icon.tooltip_text = "Hunter Stance" if stance == &"hunter" else "Steel Stance" if stance == &"steel" else "Royal Stance"
	_update_magic(forest.player.magic, ForestPrince.MAX_MAGIC)
	if stance_tween and stance_tween.is_valid():
		stance_tween.kill()
	stance_icon.modulate = Color(0.75, 2.0, 0.95) if stance == &"hunter" else Color(1.7, 1.9, 2.0) if stance == &"steel" else Color(2.0, 1.65, 0.7)
	stance_tween = create_tween()
	stance_tween.tween_property(stance_icon, "modulate", Color.WHITE, 0.6)

func _update_essence(amount: int) -> void:
	essence_count.text = "?" if forest.player.god_mode else str(amount)

func _on_essence_discovered() -> void:
	_play_sound(&"item")
	_show_item_reveal(&"essence")

func _on_essence_collected() -> void:
	_play_sound(&"essence")

func _on_shakchunni_essence_collected() -> void:
	_play_sound(&"item")
	_show_item_reveal(&"shakchunni_essence")

func _on_amulet_equipped() -> void:
	_play_sound(&"item")
	_update_magic(forest.player.magic, ForestPrince.MAX_MAGIC)
	if mode != &"merchant":
		_show_item_reveal(&"amulet")

func _on_blood_amulet_collected() -> void:
	_play_sound(&"item")
	_show_item_reveal(&"blood")

func _on_sword_equipped() -> void:
	_play_sound(&"item")
	_show_item_reveal(&"sword")

func _show_overlay() -> void:
	get_tree().paused = true
	overlay.show()
	primary.grab_focus()
	pause_button.disabled = true

func resume_journey() -> void:
	if mode != &"paused":
		return
	mode = &"playing"
	character_menu.hide()
	menu_resume.release_focus()
	overlay.hide()
	primary.release_focus()
	pause_button.disabled = false
	_release_actions()
	get_tree().paused = false

func restart_journey() -> void:
	var use_checkpoint := mode == &"defeated" and forest.checkpoint_active
	if reveal_tween and reveal_tween.is_valid():
		reveal_tween.kill()
	amulet_reveal.hide()
	amulet_reveal.modulate = Color.WHITE
	merchant.hide()
	character_menu.hide()
	skill_tree.hide()
	rest_menu.hide()
	if victory_tween and victory_tween.is_valid():
		victory_tween.kill()
	victory_screen.hide()
	mode = &"playing"
	overlay.hide()
	primary.release_focus()
	pause_button.disabled = false
	_release_actions()
	if use_checkpoint:
		forest.recover_at_fountain()
	else:
		forest.reset_journey()
	get_tree().paused = false

func _release_actions() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"heal", &"interact"]:
		Input.action_release(action)

func _build_boss_hud() -> void:
	boss_panel = Control.new()
	boss_panel.name = "BossHealth"
	boss_panel.position = Vector2(190, 610)
	boss_panel.size = Vector2(900, 80)
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(boss_panel)
	boss_title = _label(boss_panel, "SHAKCHUNNI, REAPER OF FOREST", Vector2(0, 0), 23, Color("e4d4c7"), serif)
	boss_title.size = Vector2(900, 32)
	boss_title.add_theme_constant_override("outline_size", 5)
	boss_title.add_theme_color_override("font_outline_color", Color("120e1b"))
	boss_health = ProgressBar.new()
	boss_health.name = "HealthBar"
	boss_health.position = Vector2(0, 38)
	boss_health.size = Vector2(900, 18)
	boss_health.max_value = 32
	boss_health.value = 32
	boss_health.show_percentage = false
	boss_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health.add_theme_stylebox_override("background", _box(Color("1d1b25"), Color("907e85"), 3))
	boss_health.add_theme_stylebox_override("fill", _box(Color("ad394e"), Color.TRANSPARENT, 3))
	boss_panel.add_child(boss_health)
	boss_phase = _label(boss_panel, "", Vector2(0, 70), 13, Color("d5a7d9"), italic)
	boss_phase.size.x = 900
	boss_panel.hide()

func _on_boss_started() -> void:
	boss_title.text = "SHAKCHUNNI, REAPER OF FOREST"
	_set_boss_music(true)
	boss_panel.show()
	_update_boss_health(forest.boss_arena.boss.health, forest.boss_arena.boss.MAX_HEALTH)

func _on_boss_reset() -> void:
	_set_boss_music(false)
	boss_panel.hide()
	boss_phase.text = ""

func _update_boss_health(current: int, maximum: int) -> void:
	boss_health.max_value = maximum
	boss_health.value = current

func _update_boss_phase(phase: StringName) -> void:
	if phase == &"laugh":
		boss_phase.text = "Her laughter makes her untouchable..."
	elif forest.boss_arena.boss.frenzy_left > 0.0 and phase != &"dead":
		boss_phase.text = "FRENZIED"
	else:
		boss_phase.text = ""

func _build_rest_menu() -> void:
	rest_menu = Control.new()
	rest_menu.name = "RestMenu"
	rest_menu.size = Vector2(1280, 720)
	rest_menu.z_index = 24
	rest_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(rest_menu)
	var shade := ColorRect.new()
	shade.size = rest_menu.size
	shade.color = Color(0.01, 0.025, 0.025, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_menu.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(55, 145)
	panel.size = Vector2(400, 430)
	var style := _box(Color(0.025, 0.055, 0.05, 0.94), Color("8c7c55"), 3)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	rest_menu.add_child(panel)
	_label(panel, "THE FOUNTAIN", Vector2(32, 27), 12, GOLD)
	_label(panel, "A moment of rest", Vector2(32, 53), 27, PAPER, serif)
	var descriptions := ["CONTEMPLATE", "MEDITATE", "LEAVE"]
	for i in range(descriptions.size()):
		var button := _button(descriptions[i], Vector2(32, 125 + i * 59), Vector2(336, 48))
		button.name = descriptions[i].capitalize()
		panel.add_child(button)
		rest_buttons.append(button)
	rest_buttons[0].pressed.connect(_open_merchant)
	rest_buttons[1].pressed.connect(_meditate)
	rest_buttons[2].pressed.connect(_leave_rest)
	rest_message = _label(panel, "", Vector2(32, 325), 14, MUTED, italic)
	rest_message.size = Vector2(336, 55)
	rest_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_menu.hide()

func _open_rest_menu() -> void:
	if mode != &"playing":
		return
	mode = &"resting"
	pause_button.disabled = true
	_release_actions()
	rest_message.text = ""
	rest_menu.show()
	rest_buttons[0].grab_focus()

func _meditate() -> void:
	if mode != &"resting":
		return
	rest_menu.hide()
	mode = &"skill_tree"
	get_tree().paused = true
	_release_actions()
	skill_tree.show()
	_refresh_skill_tree()
	skill_buttons[0].grab_focus()

func _leave_rest() -> void:
	if mode != &"resting":
		return
	rest_menu.hide()
	for button in rest_buttons:
		button.release_focus()
	forest.player.stop_resting()
	mode = &"playing"
	pause_button.disabled = false
	_release_actions()
	get_tree().paused = false

func _build_skill_tree() -> void:
	skill_tree = Control.new()
	skill_tree.name = "SkillTree"
	skill_tree.size = Vector2(1280, 720)
	skill_tree.z_index = 25
	skill_tree.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(skill_tree)
	var shade := ColorRect.new()
	shade.size = skill_tree.size
	shade.color = Color(0.01, 0.025, 0.025, 0.88)
	skill_tree.add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(120, 80)
	panel.size = Vector2(1040, 560)
	panel.add_theme_stylebox_override("panel", _box(Color("102b2b"), Color("928661"), 5))
	skill_tree.add_child(panel)
	_label(panel, "ROYAL STANCE", Vector2(42, 25), 12, GOLD)
	_label(panel, "The Prince's Path", Vector2(42, 48), 30, PAPER, serif)
	_label(panel, "Choose a skill to learn more", Vector2(42, 91), 14, MUTED, italic)
	for i in range(2):
		var link := ColorRect.new()
		link.name = "Connection%d" % i
		link.position = Vector2(245, 230 + i * 132)
		link.size = Vector2(2, 26)
		link.color = GOLD
		link.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(link)
	var names := ["Royal Stance", "Royal Stance II", "Blood Blade"]
	for i in range(3):
		var node := _button("", Vector2(80, 130 + i * 132), Vector2(330, 100))
		node.name = "Skill%d" % i
		panel.add_child(node)
		skill_buttons.append(node)
		var art := TextureRect.new()
		art.name = "Icon"
		art.texture = BLOOD_BLADE_ICON if i == 2 else ROYAL_STANCE_ICON
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)
		art.position = Vector2(12, 10)
		art.size = Vector2(80, 80)
		var name_label := _label(node, names[i], Vector2(105, 10), 18, PAPER, serif)
		name_label.size = Vector2(215, 28)
		var coin := TextureRect.new()
		coin.name = "EssenceIcon"
		coin.texture = ESSENCE_COIN
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(coin)
		coin.position = Vector2(102, 43)
		coin.size = Vector2(24, 24)
		skill_coins.append(coin)
		var price := _label(node, "", Vector2(130, 45), 15, GOLD)
		price.name = "Cost"
		price.size = Vector2(190, 22)
		skill_costs.append(price)
		if i == 2:
			skill_amulet_icon = TextureRect.new()
			skill_amulet_icon.name = "AmuletIcon"
			skill_amulet_icon.texture = BLOOD_AMULET_TEXTURE
			skill_amulet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skill_amulet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skill_amulet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(skill_amulet_icon)
			skill_amulet_icon.position = Vector2(102, 70)
			skill_amulet_icon.size = Vector2(24, 24)
			skill_item_requirement = _label(node, "BLOOD AMULET", Vector2(130, 72), 12, PAPER)
			skill_item_requirement.name = "ItemRequirement"
			skill_item_requirement.size = Vector2(190, 20)
		var index := i
		node.focus_entered.connect(func() -> void: _select_skill(index))
		node.mouse_entered.connect(func() -> void: node.grab_focus())
		node.pressed.connect(_purchase_selected_skill)
	skill_title = _label(panel, "", Vector2(500, 160), 23, GOLD, serif)
	skill_description = _label(panel, "", Vector2(500, 205), 16, PAPER, italic)
	skill_description.size = Vector2(430, 150)
	skill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_back = _button("RETURN TO FOUNTAIN", Vector2(730, 492), Vector2(240, 42))
	skill_back.name = "Back"
	skill_back.pressed.connect(_close_skill_tree)
	panel.add_child(skill_back)
	skill_tree.hide()

func _select_skill(index: int) -> void:
	skill_selected = index
	var titles := ["Royal Stance", "Royal Stance Level 2", "Blood Blade"]
	var descriptions := ["The prince's balanced sword stance.", "A deeper mastery of the Royal Stance.", "Sacrifices health at a steady rate for increased range."]
	skill_title.text = titles[index]
	skill_description.text = descriptions[index]
	if index == 2 and not forest.royal_level_2_unlocked:
		skill_description.text += "  Requires Royal Stance Level 2."

func _refresh_skill_tree() -> void:
	var owned := [true, forest.royal_level_2_unlocked, forest.blood_blade_unlocked]
	var prices := [0, forest.ROYAL_LEVEL_2_PRICE, forest.BLOOD_BLADE_PRICE]
	for i in range(3):
		skill_buttons[i].modulate = Color(1.0, 0.88, 0.55) if owned[i] else Color.WHITE
		skill_costs[i].text = "PURCHASED" if owned[i] else "%d ESSENCE" % prices[i]
		skill_coins[i].visible = not owned[i]
		skill_costs[i].position.x = 105 if owned[i] else 130
		var affordable: bool = forest.player.god_mode or forest.essence >= prices[i]
		skill_costs[i].add_theme_color_override("font_color", GOLD if owned[i] or affordable else Color("f07373"))
	skill_item_requirement.visible = not forest.blood_blade_unlocked
	skill_amulet_icon.visible = not forest.blood_blade_unlocked
	skill_item_requirement.add_theme_color_override("font_color", PAPER if forest.player.has_blood_amulet else Color("f07373"))
	_select_skill(skill_selected)

func _purchase_selected_skill() -> void:
	var ids: Array[StringName] = [&"royal", &"royal_2", &"blood_blade"]
	if forest.purchase_skill(ids[skill_selected]):
		_play_sound(&"item")
		_refresh_skill_tree()

func _close_skill_tree() -> void:
	if mode != &"skill_tree":
		return
	skill_tree.hide()
	mode = &"resting"
	get_tree().paused = false
	rest_menu.show()
	rest_buttons[1].grab_focus()
	_release_actions()

func _build_merchant() -> void:
	merchant = Control.new()
	merchant.name = "Merchant"
	merchant.size = Vector2(1280, 720)
	merchant.z_index = 25
	merchant.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(merchant)
	var shade := ColorRect.new()
	shade.size = merchant.size
	shade.color = Color(0.015, 0.055, 0.05, 0.82)
	merchant.add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(330, 25)
	panel.size = Vector2(620, 650)
	panel.add_theme_stylebox_override("panel", _box(Color("102b2b"), Color("928661"), 5))
	merchant.add_child(panel)
	_label(panel, "The Fountain Merchant", Vector2(40, 25), 30, PAPER, serif)
	_label(panel, "A quiet exchange for a wandering prince", Vector2(40, 70), 15, MUTED, italic)
	merchant_buy = _merchant_item(panel, "SteelStance", "Steel Stance", STEEL_STANCE_ICON, forest.STEEL_STANCE_PRICE, Vector2(75, 95))
	merchant_buy.pressed.connect(_buy_steel_stance)
	merchant_healing = _merchant_item(panel, "HealingAmulet", "Healing Amulet", AMULET_TEXTURE, forest.HEALING_AMULET_PRICE, Vector2(345, 95))
	merchant_healing.pressed.connect(_buy_healing_amulet)
	merchant_hunter = _merchant_item(panel, "HunterStance", "Hunter Stance", HUNTER_STANCE_ICON, forest.HUNTER_STANCE_PRICE, Vector2(210, 305))
	merchant_hunter.pressed.connect(_buy_hunter_stance)
	merchant_hunter.tooltip_text = "Hunter Stance"
	var hunter_requirement := TextureRect.new()
	hunter_requirement.name = "ShakchunniEssenceIcon"
	hunter_requirement.texture = SHAKCHUNNI_ESSENCE_ICON
	hunter_requirement.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hunter_requirement.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hunter_requirement.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hunter_requirement.position = Vector2(11, 163)
	hunter_requirement.size = Vector2(34, 34)
	hunter_requirement.tooltip_text = "Essence of Shakchunni required"
	merchant_hunter.add_child(hunter_requirement)
	var hunter_coin := merchant_hunter.get_node("EssenceIcon") as TextureRect
	hunter_coin.position = Vector2(56, 168)
	hunter_coin.size = Vector2(25, 25)
	var hunter_cost := merchant_hunter.get_node("CostLabel") as Label
	hunter_cost.text = "%d Essence" % forest.HUNTER_STANCE_PRICE
	hunter_cost.position = Vector2(87, 169)
	hunter_cost.size = Vector2(110, 25)
	hunter_cost.add_theme_font_size_override("font_size", 14)
	merchant_status = _label(panel, "", Vector2(40, 515), 15, MUTED)
	merchant_status.size.x = 540
	merchant_close = _button("LEAVE MERCHANT", Vector2(40, 555), Vector2(540, 44))
	merchant_close.pressed.connect(_close_merchant)
	panel.add_child(merchant_close)
	merchant.hide()

func _merchant_item(parent: Control, item_name: String, title: String, texture: Texture2D, cost: int, at: Vector2) -> Button:
	var item := _button("", at, Vector2(200, 200))
	item.name = item_name
	parent.add_child(item)
	var art := TextureRect.new()
	art.name = "Icon"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(art)
	art.position = Vector2(40, 12)
	art.size = Vector2(120, 120)
	var name_label := _label(item, title, Vector2(0, 137), 18, PAPER, serif)
	name_label.size = Vector2(200, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var coin := TextureRect.new()
	coin.name = "EssenceIcon"
	coin.texture = ESSENCE_COIN
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(coin)
	coin.position = Vector2(58, 166)
	coin.size = Vector2(29, 29)
	var cost_label := _label(item, str(cost), Vector2(91, 170), 16, GOLD)
	cost_label.name = "CostLabel"
	return item

func _focus_merchant_item() -> void:
	if not merchant_buy.disabled:
		merchant_buy.grab_focus()
	elif not merchant_healing.disabled:
		merchant_healing.grab_focus()
	elif not merchant_hunter.disabled:
		merchant_hunter.grab_focus()
	else:
		merchant_close.grab_focus()

func _open_merchant() -> void:
	if mode != &"resting" or not forest.player.is_resting:
		return
	rest_menu.hide()
	mode = &"merchant"
	get_tree().paused = true
	pause_button.disabled = true
	_release_actions()
	_refresh_merchant()
	merchant.show()
	_focus_merchant_item()

func _refresh_merchant() -> void:
	merchant_buy.disabled = forest.has_steel_stance or (not forest.player.god_mode and forest.essence < forest.STEEL_STANCE_PRICE)
	merchant_healing.disabled = forest.player.has_amulet or (not forest.player.god_mode and forest.essence < forest.HEALING_AMULET_PRICE)
	merchant_hunter.disabled = not forest.has_shakchunni_essence or forest.has_hunter_stance or (not forest.player.god_mode and forest.essence < forest.HUNTER_STANCE_PRICE)
	merchant_buy.modulate = Color(0.4, 0.4, 0.4) if merchant_buy.disabled else Color.WHITE
	merchant_healing.modulate = Color(0.4, 0.4, 0.4) if merchant_healing.disabled else Color.WHITE
	merchant_hunter.modulate = Color(0.4, 0.4, 0.4) if merchant_hunter.disabled else Color.WHITE
	merchant_status.text = "Unlimited Essence (God Mode)" if forest.player.god_mode else "You have %d Essence" % forest.essence

func _buy_steel_stance() -> void:
	if forest.purchase_steel_stance():
		_play_sound(&"item")
		_refresh_merchant()
		_show_item_reveal(&"steel")

func _buy_healing_amulet() -> void:
	if forest.purchase_healing_amulet():
		_refresh_merchant()
		_show_item_reveal(&"amulet")

func _buy_hunter_stance() -> void:
	if forest.purchase_hunter_stance():
		_play_sound(&"item")
		_refresh_merchant()
		_show_item_reveal(&"hunter")

func _close_merchant() -> void:
	if mode != &"merchant":
		return
	merchant.hide()
	merchant_buy.release_focus()
	merchant_healing.release_focus()
	merchant_hunter.release_focus()
	merchant_close.release_focus()
	mode = &"resting"
	rest_menu.show()
	rest_buttons[0].grab_focus()
	_release_actions()
	get_tree().paused = false

func _build_chrome() -> void:
	var border := Panel.new()
	border.position = Vector2(-1, -1)
	border.size = Vector2(1282, 722)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, Color("567064")))
	frame.add_child(border)
	# Keep the former decorative emblem available without showing it in the HUD.
	var emblem := Panel.new()
	emblem.name = "HiddenHudEmblem"
	emblem.position = Vector2(30, 28)
	emblem.size = Vector2(36, 36)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_theme_stylebox_override("panel", _box(Color(0.04, 0.10, 0.1, 0.4), Color("b5a16d"), 18))
	frame.add_child(emblem)
	_label(emblem, "?", Vector2(9, 4), 22, GOLD)
	emblem.hide()
	pause_button = _button("II   PAUSE", Vector2(1100, 27), Vector2(150, 37))
	pause_button.tooltip_text = "Pause the journey (Esc / controller Start)"
	pause_button.pressed.connect(pause_journey)
	frame.add_child(pause_button)
	pause_button.hide()
	god_mode_indicator = _label(frame, "GOD MODE", Vector2(270, 32), 14, GOLD)
	god_mode_indicator.add_theme_constant_override("outline_size", 4)
	god_mode_indicator.add_theme_color_override("font_outline_color", Color("102526"))
	god_mode_indicator.hide()
	_build_combat_hud()
	_build_essence_hud()
	var x: float = 40
	for group in [["A", "D", "MOVE"], ["←", "→", "STANCE"], ["SPACE", "JUMP"], ["J / X", "ATTACK"], ["H", "HEAL"], ["R", "RESTART"]]:
		for token: String in group:
			if token in ["MOVE", "STANCE", "JUMP", "ATTACK", "HEAL", "PAUSE", "RESTART"]:
				var name_label := _label(interface, token, Vector2(x + 3, 877), 10, MUTED)
				x += name_label.get_minimum_size().x + 33
			elif token == "or":
				_label(interface, token, Vector2(x + 2, 873), 13, Color("77918b"), italic)
				x += 25
			else:
				var width: float = 60 if token == "SPACE" else 42 if token == "J / X" else 34 if token == "ESC" else 27
				var key := Panel.new()
				key.position = Vector2(x, 870)
				key.size = Vector2(width, 29)
				key.mouse_filter = Control.MOUSE_FILTER_IGNORE
				key.add_theme_stylebox_override("panel", _box(Color("1b302d"), Color("526961"), 3))
				interface.add_child(key)
				var key_label := _label(key, token, Vector2.ZERO, 11, Color("d4dfd2"))
				key_label.size = key.size
				key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				x += width + 6
	var bottom_star := _label(interface, "?", Vector2(1302, 872), 20, GOLD)
	bottom_star.name = "HiddenBottomStar"
	bottom_star.hide()

func _build_essence_hud() -> void:
	var panel := Panel.new()
	panel.name = "EssenceCounter"
	panel.position = Vector2(1130, 20)
	panel.size = Vector2(120, 44)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color(0.035, 0.09, 0.10, 0.86), Color("526d73"), 5))
	frame.add_child(panel)
	var icon := TextureRect.new()
	icon.name = "EssenceIcon"
	icon.texture = ESSENCE_COIN
	icon.position = Vector2(4, 2)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	icon.size = Vector2(40, 40)
	essence_count = _label(panel, "0", Vector2(46, 7), 21, Color("effaff"))
	essence_count.name = "Amount"
	essence_count.size = Vector2(64, 30)
	essence_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	essence_count.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_combat_hud() -> void:
	combat_panel = Panel.new()
	combat_panel.position = Vector2(28, 20)
	combat_panel.size = Vector2(206, 41)
	combat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_panel.add_theme_stylebox_override("panel", _box(Color(0.035, 0.09, 0.08, 0.86), Color("52695a"), 5))
	frame.add_child(combat_panel)
	health_bar = _resource_bar(combat_panel, Vector2(8, 7), Color("c94b4b"))
	stamina_bar = _resource_bar(combat_panel, Vector2(8, 24), Color("79c977"))
	magic_bar = _resource_bar(combat_panel, Vector2(8, 41), Color("4fa7e8"))
	magic_bar.hide()
	stance_icon = TextureRect.new()
	stance_icon.name = "StanceIcon"
	stance_icon.texture = ROYAL_STANCE_ICON
	stance_icon.tooltip_text = "Royal Stance"
	stance_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stance_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stance_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stance_icon.position = Vector2(28, 133)
	stance_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stance_icon)
	stance_icon.size = Vector2(30, 30)

func _resource_bar(parent: Control, at: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.step = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# With no percentage text, avoid a font minimum overriding the bar height.
	bar.add_theme_font_size_override("font_size", 1)
	bar.add_theme_stylebox_override("background", _box(Color("192e27"), Color("52695a"), 3))
	bar.add_theme_stylebox_override("fill", _box(fill, Color.TRANSPARENT, 3))
	parent.add_child(bar)
	bar.size = Vector2(190, 10)
	return bar

func _build_amulet_reveal() -> void:
	amulet_reveal = Control.new()
	amulet_reveal.name = "AmuletReveal"
	amulet_reveal.size = Vector2(1280, 720)
	amulet_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	amulet_reveal.z_index = 30
	frame.add_child(amulet_reveal)
	reveal_shade = ColorRect.new()
	reveal_shade.size = amulet_reveal.size
	reveal_shade.color = Color(0.015, 0.055, 0.075, 0.0)
	amulet_reveal.add_child(reveal_shade)
	reveal_halo = Panel.new()
	reveal_halo.position = Vector2(490, 72)
	reveal_halo.size = Vector2(300, 300)
	reveal_halo.pivot_offset = reveal_halo.size * 0.5
	var halo_style := _box(Color(0.08, 0.38, 0.48, 0.12), Color(0.49, 0.9, 1.0, 0.7), 150)
	halo_style.set_border_width_all(3)
	halo_style.shadow_color = Color(0.2, 0.8, 1.0, 0.4)
	halo_style.shadow_size = 30
	reveal_halo.add_theme_stylebox_override("panel", halo_style)
	amulet_reveal.add_child(reveal_halo)
	reveal_art = TextureRect.new()
	reveal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reveal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reveal_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	reveal_art.texture = AMULET_TEXTURE
	amulet_reveal.add_child(reveal_art)
	reveal_art.position = Vector2(515, 88)
	reveal_art.size = Vector2(250, 250)
	reveal_art.pivot_offset = reveal_art.size * 0.5
	reveal_sword = Node2D.new()
	reveal_sword.set_script(SWORD_REVEAL_VISUAL)
	reveal_sword.aura = true
	reveal_sword.position = Vector2(640, 300)
	amulet_reveal.add_child(reveal_sword)
	reveal_sword.hide()
	reveal_title = _label(amulet_reveal, "HEALING AMULET AWAKENED", Vector2(240, 390), 29, Color("d8f5ff"), serif)
	reveal_title.z_index = 1
	reveal_title.size = Vector2(800, 48)
	reveal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_title.add_theme_constant_override("outline_size", 7)
	reveal_title.add_theme_color_override("font_outline_color", Color("092c3b"))
	reveal_copy = _label(amulet_reveal, "Allows the user the magic of healing.", Vector2(240, 446), 18, Color("a8dfed"), italic)
	reveal_copy.size = Vector2(800, 36)
	reveal_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(14):
		var spark := _label(amulet_reveal, "✦", Vector2(632, 220), 18 + i % 3 * 4, Color("b9f4ff"))
		spark.pivot_offset = Vector2(10, 10)
		reveal_sparks.append(spark)
	amulet_reveal.hide()

func _show_item_reveal(item: StringName) -> void:
	reveal_returns_to_merchant = mode == &"merchant"
	mode = &"item_reveal"
	get_tree().paused = true
	pause_button.disabled = true
	_release_actions()
	amulet_reveal.modulate = Color.WHITE
	reveal_shade.color.a = 0.0
	var blood_reveal := item == &"blood"
	var green_reveal := item in [&"hunter", &"shakchunni_essence"]
	reveal_halo.modulate = Color(0.38, 1.0, 0.55) if green_reveal else Color(1.0, 0.35, 0.35) if blood_reveal else Color.WHITE
	reveal_title.add_theme_color_override("font_color", Color("c8ffd3") if green_reveal else Color("ffd4c7") if blood_reveal else Color("d8f5ff"))
	reveal_copy.add_theme_color_override("font_color", Color("a6e8b4") if green_reveal else Color("f5b8ad") if blood_reveal else Color("a8dfed"))
	var sword_reveal := item == &"sword"
	reveal_art.visible = not sword_reveal
	reveal_sword.visible = sword_reveal
	match item:
		&"sword":
			reveal_title.text = "FOREST BLADE AWAKENED"
			reveal_copy.text = "Allows the user to wield the Forest Blade."
		&"steel":
			reveal_art.texture = STEEL_STANCE_ICON
			reveal_title.text = "STEEL STANCE AWAKENED"
			reveal_copy.text = "A defensive stance for blocking and countering attacks."
		&"hunter":
			reveal_art.texture = HUNTER_STANCE_ICON
			reveal_title.text = "HUNTER STANCE AWAKENED"
			reveal_copy.text = "Hunt from afar with spirit arrows and evade danger with a swift roll."
		&"shakchunni_essence":
			reveal_art.texture = SHAKCHUNNI_ESSENCE_ICON
			reveal_title.text = "ESSENCE OF SHAKCHUNNI"
			reveal_copy.text = "When the hunter becomes prey, an apex hunter is born."
		&"blood":
			reveal_art.texture = BLOOD_AMULET_TEXTURE
			reveal_title.text = "BLOOD AMULET DISCOVERED"
			reveal_copy.text = "An ancient amulet pulsing with a mysterious crimson power."
		&"essence":
			reveal_art.texture = ESSENCE_COIN
			reveal_title.text = "ESSENCE DISCOVERED"
			reveal_copy.text = "Essence is gathered from the spirits of fallen foes."
		_:
			reveal_art.texture = AMULET_TEXTURE
			reveal_title.text = "HEALING AMULET AWAKENED"
			reveal_copy.text = "Allows the user the magic of healing."
	var item_art: CanvasItem = reveal_sword if sword_reveal else reveal_art
	var final_scale := Vector2.ONE * (4.0 if sword_reveal else 1.0)
	item_art.modulate.a = 0.0
	item_art.scale = final_scale * 0.12
	item_art.rotation = -0.16
	reveal_halo.modulate.a = 0.0
	reveal_halo.scale = Vector2.ONE * 0.25
	reveal_title.modulate.a = 0.0
	reveal_copy.modulate.a = 0.0
	for i in range(reveal_sparks.size()):
		var spark := reveal_sparks[i]
		spark.position = Vector2(632, 220)
		spark.modulate.a = 0.0
	amulet_reveal.show()
	reveal_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal_tween.tween_property(reveal_shade, "color:a", 0.88, 0.25)
	reveal_tween.parallel().tween_property(item_art, "modulate:a", 1.0, 0.25)
	reveal_tween.parallel().tween_property(item_art, "scale", final_scale, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.parallel().tween_property(item_art, "rotation", 0.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal_tween.parallel().tween_property(reveal_halo, "modulate:a", 1.0, 0.35)
	reveal_tween.parallel().tween_property(reveal_halo, "scale", Vector2.ONE, 0.82).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tween.parallel().tween_property(reveal_title, "modulate:a", 1.0, 0.35).set_delay(0.45)
	reveal_tween.parallel().tween_property(reveal_copy, "modulate:a", 1.0, 0.45).set_delay(0.45)
	for i in range(reveal_sparks.size()):
		var angle := float(i) * TAU / float(reveal_sparks.size())
		var distance := 155.0 + float(i % 3) * 28.0
		var destination := Vector2(632, 220) + Vector2(cos(angle), sin(angle)) * distance
		reveal_tween.parallel().tween_property(reveal_sparks[i], "position", destination, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.parallel().tween_property(reveal_sparks[i], "modulate:a", 0.9, 0.32)
	reveal_tween.tween_interval(1.65)
	reveal_tween.tween_property(amulet_reveal, "modulate:a", 0.0, 0.35)
	reveal_tween.tween_callback(_finish_item_reveal)

func _finish_item_reveal() -> void:
	amulet_reveal.hide()
	amulet_reveal.modulate = Color.WHITE
	if mode == &"item_reveal":
		if reveal_returns_to_merchant:
			mode = &"merchant"
			_refresh_merchant()
			_focus_merchant_item()
		else:
			mode = &"playing"
			pause_button.disabled = false
			get_tree().paused = false
	reveal_returns_to_merchant = false

func _build_victory_screen() -> void:
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	victory_screen.size = Vector2(1280, 720)
	victory_screen.z_index = 40
	frame.add_child(victory_screen)
	var grayscale := ColorRect.new()
	grayscale.name = "Grayscale"
	grayscale.size = victory_screen.size
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(scene, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray * 0.42), 1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	grayscale.material = material
	victory_screen.add_child(grayscale)
	var script_font := SystemFont.new()
	script_font.font_names = PackedStringArray(["Segoe Script", "Lucida Handwriting", "Brush Script MT", "cursive"])
	script_font.font_italic = true
	var title := _label(victory_screen, "The Prince Prevails", Vector2(80, 260), 70, Color("e8c979"), script_font)
	title.name = "Title"
	title.size = Vector2(1120, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color("483817"))
	var restart := _button("WALK AGAIN", Vector2(515, 465), Vector2(250, 48))
	restart.name = "Restart"
	restart.pressed.connect(restart_journey)
	victory_screen.add_child(restart)
	var restart_hint := _label(victory_screen, "Press R to restart", Vector2(440, 525), 14, Color("d1c6a4"), italic)
	restart_hint.size.x = 400
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_screen.hide()

func _build_character_menu() -> void:
	character_menu = Control.new()
	character_menu.name = "CharacterMenu"
	character_menu.size = Vector2(1280, 720)
	character_menu.z_index = 20
	character_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(character_menu)
	var shade := ColorRect.new()
	shade.size = character_menu.size
	shade.color = Color(0.012, 0.035, 0.03, 0.88)
	character_menu.add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(70, 55)
	panel.size = Vector2(1140, 610)
	var panel_style := _box(Color("102b2b"), Color("928661"), 5)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 25
	panel.add_theme_stylebox_override("panel", panel_style)
	character_menu.add_child(panel)
	_label(panel, "THE PRINCE", Vector2(34, 22), 12, GOLD)
	_label(panel, "Journey paused", Vector2(34, 46), 30, PAPER, serif)
	_label(panel, "INVENTORY", Vector2(36, 112), 13, GOLD)
	_label(panel, "ATTRIBUTES", Vector2(405, 112), 13, GOLD)
	_label(panel, "STANCE DIRECTIONS", Vector2(760, 112), 13, GOLD)
	_menu_inventory_item(panel, "sword", "Forest Blade", null)
	_menu_inventory_item(panel, "healing", "Healing Amulet", AMULET_TEXTURE)
	_menu_inventory_item(panel, "blood", "Blood Amulet", BLOOD_AMULET_TEXTURE)
	_menu_inventory_item(panel, "essence", "Essence", ESSENCE_COIN)
	_menu_inventory_item(panel, "shakchunni_essence", "Essence of Shakchunni", SHAKCHUNNI_ESSENCE_ICON)
	menu_item_title = _label(panel, "Inventory empty", Vector2(36, 500), 19, GOLD, serif)
	menu_item_title.size = Vector2(325, 30)
	menu_item_description = _label(panel, "Collect items on your journey.", Vector2(36, 530), 14, PAPER, italic)
	menu_item_description.size = Vector2(325, 80)
	menu_item_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stat_names := ["Health", "Stamina", "Magic", "Attack", "Counter", "Defense"]
	for i in range(stat_names.size()):
		var y := 154.0 + i * 50.0
		_label(panel, stat_names[i], Vector2(405, y), 17, PAPER)
		var value := _label(panel, "", Vector2(555, y), 17, GOLD)
		value.size.x = 145
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		menu_stats[stat_names[i]] = value
	_menu_direction_slot(panel, "up", "UP", Vector2(870, 160), HUNTER_STANCE_ICON)
	_menu_direction_slot(panel, "left", "LEFT", Vector2(755, 275), ROYAL_STANCE_ICON)
	_menu_direction_slot(panel, "right", "RIGHT", Vector2(985, 275), STEEL_STANCE_ICON)
	_menu_direction_slot(panel, "down", "DOWN", Vector2(870, 390), null)
	menu_resume = _button("CONTINUE JOURNEY", Vector2(730, 532), Vector2(365, 46), true)
	menu_resume.name = "Continue"
	menu_resume.pressed.connect(resume_journey)
	panel.add_child(menu_resume)
	_label(panel, "ESC / START  TO RETURN", Vector2(36, 550), 12, MUTED)
	character_menu.hide()

func _menu_inventory_item(parent: Control, key: String, item_name: String, texture: Texture2D) -> void:
	var item := _button("", Vector2.ZERO, Vector2(120, 105))
	item.name = "Inventory_" + key
	item.tooltip_text = item_name
	parent.add_child(item)
	if texture:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		icon.position = Vector2(20, 8)
		icon.size = Vector2(80, 80)
	else:
		var blade := Node2D.new()
		blade.name = "Icon"
		blade.set_script(SWORD_REVEAL_VISUAL)
		blade.position = Vector2(60, 78)
		blade.scale = Vector2.ONE * 1.25
		item.add_child(blade)
	item.focus_entered.connect(func() -> void: _describe_inventory_item(key))
	item.mouse_entered.connect(func() -> void: item.grab_focus())
	menu_items[key] = item

func _describe_inventory_item(key: String) -> void:
	match key:
		"sword":
			menu_item_title.text = "Forest Blade"
			menu_item_description.text = "A blade for fighting the spirits of the forest."
		"healing":
			menu_item_title.text = "Healing Amulet"
			menu_item_description.text = "Enables focused healing using magic earned from sword hits."
		"blood":
			menu_item_title.text = "Blood Amulet"
			menu_item_description.text = "An ancient amulet pulsing with a mysterious crimson power."
		"essence":
			menu_item_title.text = "Essence"
			menu_item_description.text = "The spirits of fallen foes, used to purchase items and skills.\nHeld: %s" % ("Unlimited" if forest.player.god_mode else str(forest.essence))
		"shakchunni_essence":
			menu_item_title.text = "Essence of Shakchunni"
			menu_item_description.text = "A unique spirit required to buy Hunter Stance."

func _navigate_inventory(left: bool, right: bool, up: bool, down: bool) -> void:
	if menu_visible_items.is_empty():
		menu_resume.grab_focus()
		return
	var index := -1
	for i in range(menu_visible_items.size()):
		if menu_visible_items[i].has_focus():
			index = i
			break
	if index < 0:
		menu_visible_items[menu_visible_items.size() - 1 if up else 0].grab_focus()
		return
	var next := index
	if left and index % 2 == 1:
		next = index - 1
	elif right and index % 2 == 0 and index + 1 < menu_visible_items.size():
		next = index + 1
	elif up and index >= 2:
		next = index - 2
	elif down and index + 2 < menu_visible_items.size():
		next = index + 2
	elif down:
		menu_resume.grab_focus()
		return
	menu_visible_items[next].grab_focus()

func _menu_direction_slot(parent: Control, key: String, direction: String, at: Vector2, texture: Texture2D) -> void:
	var slot := Panel.new()
	slot.name = "Direction_" + key
	slot.position = at
	slot.size = Vector2(100, 100)
	slot.add_theme_stylebox_override("panel", _box(Color(0.025, 0.075, 0.07, 0.85), Color("52695a"), 3))
	parent.add_child(slot)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	slot.add_child(icon)
	icon.position = Vector2(18, 5)
	icon.size = Vector2(64, 64)
	var label := _label(slot, direction, Vector2(0, 70), 11, MUTED)
	label.name = "DirectionLabel"
	label.size.x = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stance_slots[key] = slot

func _refresh_character_menu() -> void:
	var prince := forest.player
	menu_stats["Health"].text = "%d / %d" % [prince.health, prince.MAX_HEALTH]
	menu_stats["Stamina"].text = "%d / %d" % [roundi(prince.stamina), roundi(prince.MAX_STAMINA)]
	menu_stats["Magic"].text = "%d / %d" % [roundi(prince.magic), roundi(prince.MAX_MAGIC)] if prince.has_amulet or prince.stance == &"hunter" else "?"
	menu_stats["Attack"].text = "1 / arrow" if prince.stance == &"hunter" else "1 / hit" if prince.has_sword and prince.stance == &"royal" else "0"
	menu_stats["Counter"].text = str(prince.COUNTER_DAMAGE) if forest.has_steel_stance else "?"
	menu_stats["Defense"].text = "%d%%" % prince.defense
	menu_visible_items.clear()
	for key in ["sword", "healing", "blood", "essence", "shakchunni_essence"]:
		var available: bool = {"sword": prince.has_sword, "healing": prince.has_amulet, "blood": prince.has_blood_amulet, "essence": forest.has_discovered_essence or forest.essence > 0, "shakchunni_essence": forest.has_shakchunni_essence}[key]
		var item: Button = menu_items[key]
		item.visible = available
		if available:
			var index := menu_visible_items.size()
			item.position = Vector2(36 + (index % 2) * 145, 150 + (index / 2) * 115)
			menu_visible_items.append(item)
	if menu_visible_items.is_empty():
		menu_item_title.text = "Inventory empty"
		menu_item_description.text = "Collect items on your journey."
	else:
		for key in menu_items:
			if menu_items[key].has_focus() and menu_items[key].visible:
				_describe_inventory_item(key)
				break
	for key in ["up", "left", "right", "down"]:
		var slot: Panel = menu_stance_slots[key]
		var icon: TextureRect = slot.get_node("Icon")
		icon.visible = key == "left" or (key == "right" and forest.has_steel_stance) or (key == "up" and forest.has_hunter_stance)
		var selected: bool = (key == "left" and prince.stance == &"royal") or (key == "right" and prince.stance == &"steel" and forest.has_steel_stance) or (key == "up" and prince.stance == &"hunter" and forest.has_hunter_stance)
		slot.add_theme_stylebox_override("panel", _box(Color(0.09, 0.16, 0.11, 0.95) if selected else Color(0.025, 0.075, 0.07, 0.85), GOLD if selected else Color("52695a"), 3))
		slot.tooltip_text = "Royal Stance" if key == "left" else "Steel Stance" if key == "right" and forest.has_steel_stance else "Hunter Stance" if key == "up" and forest.has_hunter_stance else "Empty"
		var direction_label: Label = slot.get_node("DirectionLabel")
		direction_label.text = ("LEFT  ROYAL" if key == "left" else "RIGHT  STEEL" if key == "right" and forest.has_steel_stance else "UP  HUNTER" if key == "up" and forest.has_hunter_stance else key.to_upper())

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "PauseAndCompletion"
	overlay.size = Vector2(1280, 720)
	frame.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.082, 0.067, 0.78)
	shade.size = overlay.size
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(400, 146)
	panel.size = Vector2(480, 428)
	var panel_style := _box(Color("102b2b"), Color("928661"))
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)
	var symbol := _label(panel, "✦", Vector2(0, 32), 38, GOLD)
	symbol.size.x = 480
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker = _centered_label(panel, "", 100, 11, MUTED)
	heading = _centered_label(panel, "", 134, 34, PAPER, serif)
	copy = _centered_label(panel, "", 200, 16, Color("bdcbbf"), italic)
	primary = _button("", Vector2(42, 266), Vector2(396, 50), true)
	primary.pressed.connect(func() -> void:
		if mode in [&"complete", &"defeated"]:
			restart_journey()
		else:
			resume_journey())
	panel.add_child(primary)
	hint = _centered_label(panel, "", 337, 13, MUTED, italic)
	overlay.hide()

func _centered_label(parent: Control, text: String, y: float, font_size: int, color: Color, font: Font = null) -> Label:
	var result := _label(parent, text, Vector2(20, y), font_size, color, font)
	result.size.x = 440
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result

func _label(parent: Node, text: String, at: Vector2, font_size: int, color: Color, font: Font = null) -> Label:
	var result := Label.new()
	result.text = text
	result.position = at
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if font:
		result.add_theme_font_override("font", font)
	parent.add_child(result)
	return result

func _button(text: String, at: Vector2, dimensions: Vector2, filled: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.position = at
	result.size = dimensions
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size", 12)
	result.add_theme_color_override("font_color", INK if filled else PAPER)
	result.add_theme_color_override("font_focus_color", INK if filled else PAPER)
	result.add_theme_color_override("font_hover_color", INK if filled else PAPER)
	result.add_theme_color_override("font_hover_pressed_color", INK if filled else GOLD)
	result.add_theme_color_override("font_pressed_color", INK if filled else GOLD)
	result.add_theme_stylebox_override("normal", _box(GOLD if filled else Color(0.03, 0.09, 0.09, 0.7), GOLD if filled else Color("567064")))
	result.add_theme_stylebox_override("hover", _box(Color("f3dba1") if filled else Color("29443c"), GOLD))
	result.add_theme_stylebox_override("pressed", _box(Color("bca36a") if filled else Color("102b2b"), GOLD))
	var focus_style := _box(Color.TRANSPARENT, PAPER)
	focus_style.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus_style)
	return result

func _box(fill: Color, border: Color, radius: int = 0) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	return result
