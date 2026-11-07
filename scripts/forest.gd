class_name ForestLevel
extends Node2D

signal journey_complete
signal ladder_unlocked
signal essence_changed(amount: int)
signal essence_discovered

const WORLD_WIDTH: float = 7200.0
const GROUND_Y: float = 586.0
const START := Vector2(170.0, GROUND_Y)
const GOAL_X: float = 7020.0
const FOUNTAIN_X: float = 6670.0
const SWORD_PICKUP = preload("res://scripts/sword_pickup.gd")
const FOREST_ENEMY = preload("res://scripts/forest_enemy.gd")
const FOREST_BAT = preload("res://scripts/forest_bat.gd")
const MAGIC_AMULET = preload("res://scripts/magic_amulet.gd")
const PLATFORM_LOG = preload("res://assets/log.png")
const PLATFORM_SUPPORT = preload("res://assets/platform-root-support.png")
const FLOATING_ISLAND = preload("res://assets/floating-amulet-island.png")
const FOUNTAIN_TEXTURE = preload("res://assets/moss-fountain.png")
const RESTING_ARMED = preload("res://assets/prince-resting.png")
const RESTING_UNARMED = preload("res://assets/prince-resting-unarmed.png")
const FOUNTAIN_WATER = preload("res://scripts/fountain_water.gd")
const DISTANT_LEAVES = preload("res://scripts/distant_leaves.gd")
const ESSENCE_DROP = preload("res://scripts/essence_drop.gd")
# Pixel bounds of the mossy walking surface, below the decorative foliage.
# Map both the art and collision from the same source-image coordinates.
const ISLAND_DECK := Rect2(70, 270, 1570, 70)
const SUPPORT_REGION := Rect2(24, 47, 1100, 1282)

@onready var player: ForestPrince = $Prince
@onready var camera: Camera2D = $Camera
var completed: bool = false
var sword_pickup: Area2D
var amulet_pickup: MagicAmulet
var amulet_island: StaticBody2D
var enemies: Array[CharacterBody2D] = []
var bats: Array[CharacterBody2D] = []
var ladder_guardians: Array[CharacterBody2D] = []
var platforms: Array[StaticBody2D] = []
var upper_platforms: Array[StaticBody2D] = []
var beyond_platforms: Array[StaticBody2D] = []
var ladder: ForestLadder
var fountain: Node2D
var fountain_prompt: Label
var checkpoint_active := false
var essence := 0
var has_discovered_essence := false
var essence_drops: Node2D
var drop_generation := 0

func _ready() -> void:
	$Goal.body_entered.connect(_on_goal_entered)
	_build_platforms()
	_build_amulet_island()
	_build_ladder()
	essence_drops = Node2D.new()
	essence_drops.name = "EssenceDrops"
	add_child(essence_drops)
	_build_combat()
	_build_fountain()
	reset_journey()
	_animate_atmosphere()

func _process(_delta: float) -> void:
	# The original camera places the prince left of centre for a view ahead.
	camera.position.x = clampf(player.position.x + 220.0, 640.0, WORLD_WIDTH - 640.0)
	camera.position.y = clampf(player.position.y + 150.0, 100.0, 360.0)
	if fountain_prompt:
		fountain_prompt.visible = player.is_resting or _near_fountain()
		fountain_prompt.text = "PRESS ANY BUTTON TO STAND" if player.is_resting else "E / RB  REST"
	if not ladder.active and ladder_guardians.size() > 0 and ladder_guardians.all(func(bat: CharacterBody2D) -> bool: return bat.health <= 0):
		ladder.unlock()
		ladder_unlocked.emit()

func reset_journey() -> void:
	completed = false
	checkpoint_active = false
	has_discovered_essence = false
	_set_essence(0)
	player.reset_to(START)
	sword_pickup.reset_pickup()
	amulet_pickup.reset_pickup()
	_reset_enemies()
	ladder.reset_ladder()
	camera.position = Vector2(640.0, 360.0)
	camera.reset_smoothing()
	$Goal/Sparkles.restart()

func _reset_enemies() -> void:
	# Pending and uncollected drops cannot survive an enemy respawn.
	drop_generation += 1
	if essence_drops:
		for drop in essence_drops.get_children():
			drop.claimed = true
			drop.queue_free()
	for enemy in enemies:
		enemy.reset_enemy()
	for bat in bats:
		bat.reset_enemy()

func _set_essence(value: int) -> void:
	essence = maxi(0, value)
	essence_changed.emit(essence)

func _on_enemy_defeated(at: Vector2, value: int) -> void:
	# Spawn outside physics callbacks, and discard stale spawns after a reset.
	_spawn_essence.call_deferred(at, value, drop_generation)

func _spawn_essence(at: Vector2, value: int, generation: int) -> void:
	if generation != drop_generation or value <= 0:
		return
	var drop := CharacterBody2D.new()
	drop.set_script(ESSENCE_DROP)
	drop.amount = value
	drop.position = at
	drop.collected.connect(_on_essence_collected)
	essence_drops.add_child(drop)

func _on_essence_collected(value: int) -> void:
	_set_essence(essence + value)
	if not has_discovered_essence:
		has_discovered_essence = true
		essence_discovered.emit()

func _near_fountain() -> bool:
	return player.health > 0 and player.is_on_floor() and absf(player.position.x - FOUNTAIN_X) < 115.0 and absf(player.position.y - GROUND_Y) < 5.0

func try_rest() -> bool:
	if not _near_fountain() or player.is_climbing or player.is_resting:
		return false
	checkpoint_active = true
	_reset_enemies()
	var rest_texture: Texture2D = RESTING_ARMED if player.has_sword else RESTING_UNARMED
	player.begin_resting(Vector2(FOUNTAIN_X - 38.0, GROUND_Y), rest_texture)
	return true

func recover_at_fountain() -> void:
	completed = false
	_reset_enemies()
	player.recover_at_checkpoint(Vector2(FOUNTAIN_X - 38.0, GROUND_Y))
	camera.position = Vector2(minf(FOUNTAIN_X + 220.0, WORLD_WIDTH - 640.0), 360.0)
	camera.reset_smoothing()

func _build_fountain() -> void:
	fountain = Node2D.new()
	fountain.name = "RestFountain"
	fountain.position = Vector2(FOUNTAIN_X, GROUND_Y)
	add_child(fountain)
	var art := Sprite2D.new()
	art.name = "Art"
	art.texture = FOUNTAIN_TEXTURE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var bounds := art.texture.get_image().get_used_rect()
	art.region_enabled = true
	art.region_rect = bounds
	var factor := 300.0 / float(bounds.size.x)
	art.scale = Vector2.ONE * factor
	art.position.y = -float(bounds.size.y) * factor * 0.5
	art.z_index = -1
	fountain.add_child(art)
	var water := Node2D.new()
	water.name = "FlowingWater"
	water.set_script(FOUNTAIN_WATER)
	fountain.add_child(water)
	fountain_prompt = Label.new()
	fountain_prompt.position = Vector2(-150, -float(bounds.size.y) * factor - 35)
	fountain_prompt.size = Vector2(300, 24)
	fountain_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fountain_prompt.add_theme_font_size_override("font_size", 12)
	fountain_prompt.add_theme_color_override("font_color", Color("d6ebd3"))
	fountain_prompt.add_theme_constant_override("outline_size", 4)
	fountain_prompt.add_theme_color_override("font_outline_color", Color("122d2d"))
	fountain_prompt.hide()
	fountain.add_child(fountain_prompt)

func _on_goal_entered(body: Node2D) -> void:
	if body == player and player.health > 0 and not completed:
		completed = true
		journey_complete.emit()

func _build_combat() -> void:
	sword_pickup = Area2D.new()
	sword_pickup.name = "SwordPickup"
	sword_pickup.set_script(SWORD_PICKUP)
	sword_pickup.position = Vector2(450, 466)
	add_child(sword_pickup)
	for x in [3010.0, 3310.0, 3850.0, 4570.0, 5270.0, 5900.0]:
		var enemy := CharacterBody2D.new()
		enemy.set_script(FOREST_ENEMY)
		enemy.position = Vector2(x, GROUND_Y)
		enemy.player = player
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)
		enemies.append(enemy)
	var bat_positions := [Vector2(1990, 450), Vector2(2300, 285), Vector2(2590, 450), Vector2(4090, 340), Vector2(5010, 340), Vector2(5770, 400)]
	for at in bat_positions:
		var bat := CharacterBody2D.new()
		bat.set_script(FOREST_BAT)
		bat.position = at
		bat.player = player
		bat.defeated.connect(_on_enemy_defeated)
		bat.is_ladder_guardian = bats.size() < 3
		add_child(bat)
		bats.append(bat)
		if bat.is_ladder_guardian:
			ladder_guardians.append(bat)

func _build_platforms() -> void:
	# One-way branches form a reachable staircase without blocking the ground path.
	for at in [Vector2(1980, 510), Vector2(2130, 420), Vector2(2280, 330), Vector2(2430, 420), Vector2(2580, 450)]:
		platforms.append(_make_branch(at))
	# The raised route is part of the forest; the bat-gated ladder grants access.
	var upper_positions := [Vector2(1960, -55), Vector2(2280, 20), Vector2(2590, -50), Vector2(2820, -100)]
	for i in range(upper_positions.size()):
		var width := 360.0 if i == 1 else 150.0
		# Upper decks stand on distant pillars, rooted below the ground art.
		# They pass behind the lower route instead of ending on its branches.
		var platform := _make_branch(upper_positions[i], GROUND_Y + 40.0, width, true)
		upper_platforms.append(platform)
	# Two branch staircases and a shorter final ascent provide alternate paths
	# above the ground enemies in the newly opened forest.
	for at in [Vector2(3820, 510), Vector2(3970, 420), Vector2(4120, 330), Vector2(4270, 420), Vector2(4420, 510), Vector2(4770, 510), Vector2(4920, 420), Vector2(5070, 330), Vector2(5220, 420), Vector2(5370, 510), Vector2(5680, 500), Vector2(5830, 410), Vector2(5980, 320)]:
		beyond_platforms.append(_make_branch(at))
	# Familiar solid terrain makes the lower path require jumps as well.
	for obstacle in [["Log", 4200.0], ["Root", 4780.0], ["Rocks", 5530.0]]:
		var copy := get_node(obstacle[0]).duplicate() as StaticBody2D
		copy.name = "Beyond" + obstacle[0]
		copy.position.x = obstacle[1]
		add_child(copy)

func _build_amulet_island() -> void:
	amulet_island = StaticBody2D.new()
	amulet_island.name = "AmuletIsland"
	amulet_island.position = Vector2(3170, -125)
	amulet_island.collision_layer = 8
	amulet_island.collision_mask = 0
	var scale_to_width := 320.0 / float(FLOATING_ISLAND.get_width())
	var art_origin := Vector2(-160, -7)
	var deck := Rect2(art_origin + ISLAND_DECK.position * scale_to_width, ISLAND_DECK.size * scale_to_width)
	var collision := CollisionShape2D.new()
	collision.name = "DeckCollision"
	var shape := RectangleShape2D.new()
	shape.size = deck.size
	collision.shape = shape
	collision.position = deck.get_center()
	collision.one_way_collision = true
	amulet_island.add_child(collision)
	var art := Sprite2D.new()
	art.texture = FLOATING_ISLAND
	art.centered = false
	art.scale = Vector2.ONE * scale_to_width
	art.position = art_origin
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.z_index = 1
	amulet_island.add_child(art)
	add_child(amulet_island)
	amulet_pickup = MagicAmulet.new()
	amulet_pickup.name = "MagicAmulet"
	amulet_pickup.position = amulet_island.position + Vector2(0, deck.position.y)
	add_child(amulet_pickup)

func _make_branch(at: Vector2, support_base_y: float = GROUND_Y, width: float = 150.0, distant_pillar: bool = false) -> StaticBody2D:
	var branch := StaticBody2D.new()
	branch.position = at
	# Keep one-way platforms out of wall/sight rays used by ground enemies.
	branch.collision_layer = 8
	branch.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 12)
	collision.shape = shape
	collision.position.y = 6
	collision.one_way_collision = true
	branch.add_child(collision)
	# Foreground roots and background pillars occupy separate depth layers.
	var support_offsets := [-125.0, 125.0] if width > 200.0 else [0.0]
	var support_width := 145.0 if distant_pillar else 170.0
	var support_height := support_base_y - at.y + (-7.0 if distant_pillar else 5.0)
	for offset in support_offsets:
		var support := Sprite2D.new()
		support.name = "BackgroundPillar" if distant_pillar else "RootSupport"
		support.texture = PLATFORM_SUPPORT
		support.region_enabled = true
		support.region_rect = SUPPORT_REGION
		support.centered = false
		support.position = Vector2(offset - support_width * 0.5, 7)
		support.scale = Vector2(support_width / SUPPORT_REGION.size.x, support_height / SUPPORT_REGION.size.y)
		support.flip_h = (platforms.size() + upper_platforms.size()) % 2 == 1
		support.z_index = -7 if distant_pillar else -3
		if distant_pillar:
			# Cooler, quieter pillars recede behind the warm foreground roots.
			support.modulate = Color(0.62, 0.78, 0.79)
		branch.add_child(support)
	var log_count := 3 if width > 200.0 else 1
	for i in range(log_count):
		var art := Sprite2D.new()
		art.texture = PLATFORM_LOG
		art.scale = Vector2(150.0 / 464.0, 0.27)
		# Overlap the logs so the raised deck has a continuous walkable surface.
		art.position = Vector2((i - (log_count - 1) * 0.5) * 112.0, 4)
		art.z_index = 1
		branch.add_child(art)
	add_child(branch)
	return branch

func _build_ladder() -> void:
	ladder = ForestLadder.new()
	ladder.position = Vector2(2280, ForestLadder.TOP_Y)
	add_child(ladder)
	player.climb_ladder = ladder

func _animate_atmosphere() -> void:
	var leaves := Node2D.new()
	leaves.name = "DistantLeaves"
	leaves.z_index = 1
	leaves.set_script(DISTANT_LEAVES)
	$MiddleForest.add_child(leaves)
	for i in range(14):
		var mist := Sprite2D.new()
		mist.texture = preload("res://scenes/soft_glow.tres")
		mist.position = Vector2(i * 500.0 + 80.0, 530.0 + (i % 2) * 24.0)
		mist.scale = Vector2(5.3, 0.625)
		mist.modulate = Color(0.64, 0.92, 0.84, 0.045)
		mist.z_index = -1
		add_child(mist)
		var drift := create_tween().set_loops().set_parallel(true)
		drift.tween_property(mist, "position:x", mist.position.x + 70.0, 5.5 + i * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(mist, "modulate:a", 0.08, 5.5 + i * 0.35)
		drift.chain().tween_property(mist, "position:x", mist.position.x, 5.5 + i * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(mist, "modulate:a", 0.045, 5.5 + i * 0.35)
