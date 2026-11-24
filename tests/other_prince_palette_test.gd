extends SceneTree
## GPU regression: boss-only sheets keep painted skin and metal colors intact.

const PALETTE = preload("res://shaders/other_prince.gdshader")
const SHEETS := [
	["royal-combat", "prince-combat-sheet.png", 4],
	["royal-locomotion", "prince-armed-locomotion.png", 4],
	["royal-run", "prince-armed-run-v2.png", 2],
	["steel-combat", "prince-steel-combat.png", 4],
	["steel-locomotion", "prince-armed-locomotion.png", 4],
	["steel-run", "prince-armed-run-v2.png", 2]]
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for entry in SHEETS:
		var sheet: Texture2D = load("res://assets/other-prince-%s.png" % entry[0])
		var original: Texture2D = load("res://assets/" + entry[1])
		_check(sheet.get_size() == original.get_size(), "%s retains source atlas dimensions" % entry[0])
		var image := sheet.get_image()
		var cell := Vector2i(sheet.get_width() / 4, sheet.get_height() / int(entry[2]))
		for frame in range(4 * int(entry[2])):
			var origin := Vector2i(frame % 4 * cell.x, frame / 4 * cell.y)
			var blue := 0
			var skin := 0
			var silver_crown := 0
			var copper := 0
			for y in range(0, cell.y, 2):
				for x in range(0, cell.x, 2):
					var ink := image.get_pixelv(origin + Vector2i(x, y))
					if ink.a < 0.8:
						continue
					if ink.b > ink.r * 1.3 and ink.b > ink.g * 1.08:
						blue += 1
					if ink.r > 0.35 and ink.r > ink.g * 1.18 and ink.g > ink.b * 1.35 and ink.b > 0.08:
						skin += 1
						if ink.r > 0.7 and ink.g > 0.4:
							copper += 1
					if y < cell.y * 0.31 and ink.r > 0.3 and absf(ink.r - ink.g) < 0.10 and absf(ink.g - ink.b) < 0.12:
						silver_crown += 1
			_check(blue > 30 and skin > 25 and silver_crown > 2, "%s frame %d has blue cloth, natural skin and silver crown details" % [entry[0], frame])
			if String(entry[0]).begins_with("steel"):
				_check(copper > 10, "%s frame %d retains warm copper details" % [entry[0], frame])
		var viewport := SubViewport.new()
		viewport.size = Vector2i(sheet.get_width() * 2, sheet.get_height())
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for index in range(2):
			var sprite := Sprite2D.new()
			sprite.texture = sheet
			sprite.centered = false
			sprite.position.x = index * sheet.get_width()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if index == 1:
				var material := ShaderMaterial.new()
				material.shader = PALETTE
				sprite.material = material
			viewport.add_child(sprite)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var altered := 0
		for y in range(0, sheet.get_height(), 4):
			for x in range(0, sheet.get_width(), 4):
				var painted := rendered.get_pixel(x, y)
				if painted.a < 0.8:
					continue
				var boss := rendered.get_pixel(x + sheet.get_width(), y)
				if Vector3(painted.r, painted.g, painted.b).distance_to(Vector3(boss.r, boss.g, boss.b)) > 0.025:
					altered += 1
		_check(altered == 0, "%s shader preserves all sampled painted colors" % entry[0])
		viewport.queue_free()
		await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: All Other Prince stance sheets preserve skin, blue cloth and crown colors.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
