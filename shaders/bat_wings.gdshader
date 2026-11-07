shader_type canvas_item;

uniform float wing_motion = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	// Keep the bat's body steady while the wing tips move up and down.
	float wing = smoothstep(0.12, 0.48, abs(UV.x - 0.5));
	vec2 sample_uv = UV + vec2(0.0, wing_motion * wing * 0.13);
	if (sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, sample_uv) * sprite_tint;
	}
}
