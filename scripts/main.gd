extends Control
## The interface keeps processing while Godot pauses the forest subtree.

const GOLD := Color("d8be81")
const INK := Color("192921")
const PAPER := Color("f0eddb")
const MUTED := Color("93b3a2")
const INTERFACE_SIZE := Vector2(1360, 940)
const SWORD_REVEAL_VISUAL = preload("res://scripts/sword_visual.gd")
const ESSENCE_COIN = preload("res://scenes/essence_coin.tres")
const AMULET_TEXTURE = preload("res://assets/healing-amulet.png")

@onready var interface: Control = $Interface
@onready var forest: ForestLevel = $Interface/GameFrame/ViewportContainer/World/Forest
@onready var frame: Control = $Interface/GameFrame
@onready var world_image: TextureRect = $Interface/GameFrame/ViewportContainer
@onready var world: SubViewport = $Interface/GameFrame/ViewportContainer/World
var mode: StringName = &"playing"
var overlay: Control
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
var essence_count: Label
var amulet_reveal: Control
var reveal_shade: ColorRect
var reveal_halo: Panel
var reveal_art: TextureRect
var reveal_sword: Node2D
var reveal_title: Label
var reveal_copy: Label
var reveal_sparks: Array[Label] = []
var reveal_tween: Tween
var windowed_mode: Window.Mode = Window.MODE_MAXIMIZED

func _ready() -> void:
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
	_build_amulet_reveal()
	forest.journey_complete.connect(complete_journey)
	forest.player.health_changed.connect(_update_health)
	forest.player.stamina_changed.connect(_update_stamina)
	forest.player.magic_changed.connect(_update_magic)
	forest.player.sword_equipped.connect(_on_sword_equipped)
	forest.player.amulet_equipped.connect(_on_amulet_equipped)
	forest.player.died.connect(_on_player_died)
	forest.essence_changed.connect(_update_essence)
	forest.essence_discovered.connect(_on_essence_discovered)
	_update_health(forest.player.health, ForestPrince.MAX_HEALTH)
	_update_stamina(forest.player.stamina, ForestPrince.MAX_STAMINA)
	_update_magic(forest.player.magic, ForestPrince.MAX_MAGIC)
	_update_essence(forest.essence)
	world_image.texture = world.get_texture()
	get_viewport().size_changed.connect(_queue_display_resize)
	resized.connect(_queue_display_resize)
	_resize_display()

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
	if mode == &"item_reveal":
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			if reveal_tween and reveal_tween.is_valid():
				reveal_tween.kill()
			_release_actions()
			_finish_item_reveal()
		return
	if mode == &"playing" and forest.player.is_resting:
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			_release_actions()
			forest.player.stop_resting()
		return
	if mode == &"playing" and event.is_action_pressed("interact") and not event.is_echo():
		if forest.try_rest():
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

func pause_journey() -> void:
	if mode != &"playing":
		return
	mode = &"paused"
	kicker.text = "T A K E   A   B R E A T H"
	heading.text = "Paused"
	copy.text = "The forest will be here when you return."
	primary.text = "CONTINUE JOURNEY     →"
	hint.text = "Press Esc to resume"
	_show_overlay()

func complete_journey() -> void:
	mode = &"complete"
	kicker.text = "A   M O M E N T   O F   P E A C E"
	heading.text = "Forest path complete"
	copy.text = "You found your way to the light."
	primary.text = "WALK AGAIN     →"
	hint.text = "Press R to restart"
	_show_overlay()

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
	magic_bar.visible = forest.player.has_amulet
	combat_panel.size.y = 58.0 if forest.player.has_amulet else 41.0

func _update_essence(amount: int) -> void:
	essence_count.text = str(amount)

func _on_essence_discovered() -> void:
	_show_item_reveal(&"essence")

func _on_amulet_equipped() -> void:
	_update_magic(forest.player.magic, ForestPrince.MAX_MAGIC)
	_show_item_reveal(&"amulet")

func _on_sword_equipped() -> void:
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

func _build_chrome() -> void:
	_label(interface, "A  L I T T L E  J O U R N E Y  T H R O U G H  T H E  W O O D S", Vector2(40, 28), 11, MUTED)
	var title := _label(interface, "The Prince’s", Vector2(40, 49), 36, PAPER, serif)
	_label(interface, "Forest", Vector2(48 + title.get_minimum_size().x, 49), 36, Color("c8ac70"), italic)
	_label(interface, "01", Vector2(1100, 61), 25, Color("c1a76f"), italic)
	_label(interface, "THE FOREST PATH", Vector2(1145, 72), 11, MUTED)
	var border := Panel.new()
	border.position = Vector2(-1, -1)
	border.size = Vector2(1282, 722)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, Color("567064")))
	frame.add_child(border)
	var emblem := Panel.new()
	emblem.position = Vector2(30, 28)
	emblem.size = Vector2(36, 36)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_theme_stylebox_override("panel", _box(Color(0.04, 0.10, 0.1, 0.4), Color("b5a16d"), 18))
	frame.add_child(emblem)
	_label(emblem, "✦", Vector2(9, 4), 22, GOLD)
	var path_label := _label(frame, "T H E  F O R E S T  P A T H", Vector2(80, 28), 11, PAPER)
	path_label.add_theme_constant_override("outline_size", 4)
	path_label.add_theme_color_override("font_outline_color", Color("102526"))
	_label(frame, "Follow the light", Vector2(80, 47), 15, Color("d9dcc8"), italic)
	pause_button = _button("II   PAUSE", Vector2(1100, 27), Vector2(150, 37))
	pause_button.tooltip_text = "Pause the journey (Esc / controller Start)"
	pause_button.pressed.connect(pause_journey)
	frame.add_child(pause_button)
	_build_combat_hud()
	_build_essence_hud()
	var x: float = 40
	for group in [["←", "→", "or", "A", "D", "MOVE"], ["SPACE", "JUMP"], ["J / X", "ATTACK"], ["H", "HEAL"], ["ESC", "PAUSE"], ["R", "RESTART"]]:
		for token: String in group:
			if token in ["MOVE", "JUMP", "ATTACK", "HEAL", "PAUSE", "RESTART"]:
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
	_label(interface, "Find your way to the light", Vector2(1093, 874), 15, Color("8aa59a"), italic)
	_label(interface, "✦", Vector2(1302, 872), 20, GOLD)

func _build_essence_hud() -> void:
	var panel := Panel.new()
	panel.name = "EssenceCounter"
	panel.position = Vector2(1130, 76)
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
	combat_panel.position = Vector2(28, 87)
	combat_panel.size = Vector2(206, 41)
	combat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_panel.add_theme_stylebox_override("panel", _box(Color(0.035, 0.09, 0.08, 0.86), Color("52695a"), 5))
	frame.add_child(combat_panel)
	health_bar = _resource_bar(combat_panel, Vector2(8, 7), Color("c94b4b"))
	stamina_bar = _resource_bar(combat_panel, Vector2(8, 24), Color("79c977"))
	magic_bar = _resource_bar(combat_panel, Vector2(8, 41), Color("4fa7e8"))
	magic_bar.hide()

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
	var skip_hint := _label(amulet_reveal, "PRESS ANY KEY OR BUTTON, CLICK OR TAP TO SKIP", Vector2(240, 510), 13, Color("a8dfed"), sans)
	skip_hint.size = Vector2(800, 28)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(14):
		var spark := _label(amulet_reveal, "✦", Vector2(632, 220), 18 + i % 3 * 4, Color("b9f4ff"))
		spark.pivot_offset = Vector2(10, 10)
		reveal_sparks.append(spark)
	amulet_reveal.hide()

func _show_item_reveal(item: StringName) -> void:
	mode = &"item_reveal"
	get_tree().paused = true
	pause_button.disabled = true
	_release_actions()
	amulet_reveal.modulate = Color.WHITE
	reveal_shade.color.a = 0.0
	var sword_reveal := item == &"sword"
	reveal_art.visible = not sword_reveal
	reveal_sword.visible = sword_reveal
	match item:
		&"sword":
			reveal_title.text = "FOREST BLADE AWAKENED"
			reveal_copy.text = "Allows the user to wield the Forest Blade."
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
	for i in range(reveal_sparks.size()):
		var angle := float(i) * TAU / float(reveal_sparks.size())
		var distance := 155.0 + float(i % 3) * 28.0
		var destination := Vector2(632, 220) + Vector2(cos(angle), sin(angle)) * distance
		reveal_tween.parallel().tween_property(reveal_sparks[i], "position", destination, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.parallel().tween_property(reveal_sparks[i], "modulate:a", 0.9, 0.32)
	reveal_tween.tween_interval(0.12)
	reveal_tween.tween_property(reveal_title, "modulate:a", 1.0, 0.35)
	reveal_tween.parallel().tween_property(reveal_copy, "modulate:a", 1.0, 0.45)
	reveal_tween.tween_interval(1.65)
	reveal_tween.tween_property(amulet_reveal, "modulate:a", 0.0, 0.35)
	reveal_tween.tween_callback(_finish_item_reveal)

func _finish_item_reveal() -> void:
	amulet_reveal.hide()
	amulet_reveal.modulate = Color.WHITE
	if mode == &"item_reveal":
		mode = &"playing"
		pause_button.disabled = false
		get_tree().paused = false

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
