extends SceneTree

var game: Control
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.forest.player.position = Vector2(game.forest.FOUNTAIN_X - 60, game.forest.GROUND_Y)
	for i in range(5):
		await physics_frame
	_check(game.forest.try_rest() and game.mode == &"resting", "Fountain rest opens the menu")
	game.rest_buttons[1].pressed.emit()
	_check(game.mode == &"skill_tree" and paused and game.skill_tree.visible, "Meditate opens a paused skill tree")
	_check(game.skill_buttons[0].position.x == game.skill_buttons[1].position.x and game.skill_buttons[1].position.x == game.skill_buttons[2].position.x and game.skill_buttons[0].position.y < game.skill_buttons[1].position.y and game.skill_buttons[1].position.y < game.skill_buttons[2].position.y and game.skill_tree.get_node("Panel/Connection0") != null and game.skill_tree.get_node("Panel/Connection1") != null, "Skills form a connected vertical path")
	_check(game.skill_buttons[2].get_node("Icon").texture == game.BLOOD_BLADE_ICON and game.skill_amulet_icon.texture == game.BLOOD_AMULET_TEXTURE and game.skill_amulet_icon.visible, "Blood Blade and its amulet requirement have separate icons")
	_check(game.skill_costs[0].text == "PURCHASED" and game.skill_buttons[0].modulate != Color.WHITE, "Royal Stance starts purchased and tinted")
	game.skill_buttons[2].grab_focus()
	_check(game.skill_description.text.contains("health") and game.skill_description.text.contains("range"), "Focus displays Blood Blade description")
	_check(game.skill_costs[2].get_theme_color("font_color").r > game.skill_costs[2].get_theme_color("font_color").g and game.skill_item_requirement.get_theme_color("font_color").r > game.skill_item_requirement.get_theme_color("font_color").g, "Missing essence and amulet are red")
	game.forest._set_essence(400)
	game._refresh_skill_tree()
	game._purchase_selected_skill()
	_check(not game.forest.blood_blade_unlocked and game.forest.essence == 400, "Blood Blade requires earlier skill and amulet")
	game.skill_buttons[1].grab_focus()
	game._purchase_selected_skill()
	_check(game.forest.royal_level_2_unlocked and game.forest.essence == 200 and game.skill_costs[1].text == "PURCHASED", "Royal level 2 purchase spends essence and changes state")
	game._purchase_selected_skill()
	_check(game.forest.essence == 200, "Skills cannot be purchased twice")
	game.skill_buttons[2].grab_focus()
	game._purchase_selected_skill()
	_check(not game.forest.blood_blade_unlocked and game.forest.essence == 200, "Missing amulet prevents purchase")
	game.forest.player.has_blood_amulet = true
	game._refresh_skill_tree()
	_check(game.skill_item_requirement.get_theme_color("font_color") == game.PAPER, "Owned amulet requirement is no longer red")
	game._purchase_selected_skill()
	_check(game.forest.blood_blade_unlocked and game.forest.essence == 0 and game.forest.player.has_blood_amulet and not game.skill_item_requirement.visible and not game.skill_amulet_icon.visible, "Blood Blade purchase spends essence and retains amulet")
	game._close_skill_tree()
	game.forest.recover_at_fountain()
	_check(game.forest.royal_level_2_unlocked and game.forest.blood_blade_unlocked and game.forest.player.has_blood_amulet, "Checkpoint retry preserves skills and amulet")
	game.restart_journey()
	_check(not game.forest.royal_level_2_unlocked and not game.forest.blood_blade_unlocked, "New journey resets purchased skills")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All skill tree checks passed.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
