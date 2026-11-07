shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV * (1.0 - UV);
	float edge = 1.0 - pow(clamp(p.x * p.y * 16.0, 0.0, 1.0), 0.3);
	COLOR = vec4(0.015, 0.04, 0.045, edge * 0.65);
}
