shader_type canvas_item;

void fragment() {
	// Stance colors are painted into boss-only sheets. Preserve skin and crown
	// details rather than guessing their material from similar RGB values.
	if (COLOR.a < 0.035) { discard; }
}
