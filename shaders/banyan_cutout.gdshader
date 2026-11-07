shader_type canvas_item;

void fragment() {
	// The source-sheet crop includes a detached piece of the adjacent root.
	// Trim only that corner, preserving the tree's wider canopy above it.
	vec2 source_pixel = UV / TEXTURE_PIXEL_SIZE;
	if (source_pixel.x < 64.0 && source_pixel.y >= 500.0) {
		discard;
	}
}
