class_name ForestLevel
extends Node2D

signal journey_complete
signal ladder_unlocked

const WORLD_WIDTH: float = 3840.0
const GROUND_Y: float = 586.0
const START := Vector2(170.0, GROUND_Y)
const GOAL_X: float = 3550.0
const SWORD_PICKUP = preload("res://scripts/sword_pickup.gd")
const FOREST_ENEMY = preload("res://scripts/forest_enemy.gd")
const FOREST_BAT = preload("res://scripts/forest_bat.gd")
const MAGIC_AMULET = preload("res://scripts/magic_amulet.gd")
const PLATFORM_LOG = preload("res://assets/log.png")
const PLATFORM_SUPPORT = preload("res://assets/platform-root-support.png")
const FLOATING_ISLAND = preload("res://assets/floating-amulet-island.png")
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
var platforms: Array[StaticBody2D] = []
var upper_platforms: Array[StaticBody2D] = []
var ladder: ForestLadder

func _ready() -> void:
	$Goal.body_entered.connect(_on_goal_entered)
	_build_platforms()
	_build_amulet_island()
	_build_ladder()
	_build_combat()
	reset_journey()
	_animate_atmosphere()

func _process(_delta: float) -> void:
	# The original camera places the prince left of centre for a view ahead.
	camera.position.x = clampf(player.position.x + 220.0, 640.0, WORLD_WIDTH - 640.0)
	camera.position.y = clampf(player.position.y + 150.0, 100.0, 360.0)
	if not ladder.active and bats.size() > 0 and bats.all(func(bat: CharacterBody2D) -> bool: return bat.health <= 0):
		ladder.unlock()
		ladder_unlocked.emit()

func reset_journey() -> void:
	completed = false
	player.reset_to(START)
	sword_pickup.reset_pickup()
	amulet_pickup.reset_pickup()
	for enemy in enemies:
		enemy.reset_enemy()
	for bat in bats:
		bat.reset_enemy()
	ladder.reset_ladder()
	camera.position = Vector2(640.0, 360.0)
	camera.reset_smoothing()
	$Goal/Sparkles.restart()

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
	for x in [3010.0, 3310.0]:
		var enemy := CharacterBody2D.new()
		enemy.set_script(FOREST_ENEMY)
		enemy.position = Vector2(x, GROUND_Y)
		enemy.player = player
		add_child(enemy)
		enemies.append(enemy)
	for at in [Vector2(1990, 450), Vector2(2300, 285), Vector2(2590, 450)]:
		var bat := CharacterBody2D.new()
		bat.set_script(FOREST_BAT)
		bat.position = at
		bat.player = player
		add_child(bat)
		bats.append(bat)

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
	for i in range(9):
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
