shader_type canvas_item;

// Physics-driven time deliberately freezes with the encounter and pause menu.
uniform float motion_time = 0.0;
uniform float laugh = 0.0;
uniform float recoil = 0.0;
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 next_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float frame_mix = 0.0;
varying vec4 tint;

void vertex() {
    tint = COLOR;
}

void fragment() {
    vec2 p = (UV - frame_rect.xy) / frame_rect.zw;
    // Anchor the face and shoulder; let hair tips and the sari lag behind them.
    float hair = smoothstep(0.13, 0.34, abs(p.x - 0.5)) * (1.0 - smoothstep(0.45, 0.65, p.y));
    float hem = smoothstep(0.48, 0.90, p.y);
    float sway = sin(motion_time * 1.7 - p.y * 5.0);
    p.x += hair * (sin(motion_time * 2.2 - p.y * 8.0) * 0.007 + recoil * 0.008);
    p.x += hem * (sway * 0.006 + recoil * 0.012);
    p.y += hair * sin(motion_time * 2.6 + p.x * 9.0) * 0.003;
    p.y += laugh * exp(-pow((p.y - 0.23) * 9.0, 2.0)) * 0.003;
    p = clamp(p, vec2(0.002), vec2(0.998));
    vec4 a = texture(TEXTURE, frame_rect.xy + p * frame_rect.zw);
    vec4 b = texture(TEXTURE, next_rect.xy + p * next_rect.zw);
    // Premultiplied interpolation avoids dark fringes on transparent hair.
    float alpha = mix(a.a, b.a, frame_mix);
    vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, frame_mix) / max(alpha, 0.0001);
    COLOR = tint * vec4(rgb, alpha);
}
