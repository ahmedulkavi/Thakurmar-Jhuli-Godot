shader_type canvas_item;

uniform float motion_phase = 0.0;
uniform float swim = 0.0;
uniform float tension = 0.0;
uniform float burst = 0.0;
uniform int species = 0;
varying vec4 tint;

float region(vec2 p, vec2 center, vec2 radius) {
    vec2 d = (p - center) / radius;
    return exp(-dot(d, d) * 2.0);
}

void vertex() {
    tint = COLOR;
    // Extend the canvas so fins at the texture edge can move without clipping.
    VERTEX *= 1.16;
    UV = (UV - vec2(0.5)) * 1.16 + vec2(0.5);
}

void fragment() {
    // Use source-facing coordinates: the same anatomy moves when flipped.
    vec2 p = UV;
    float phase = motion_phase;
    float effort = 1.0 + swim * 1.1 + burst * 0.5;
    if (species == 0) {
        float tail = smoothstep(0.22, 0.94, p.x);
        p.y += sin(phase - p.x * 10.0) * tail * 0.042 * effort;
        p.x += cos(phase - p.x * 8.0) * tail * 0.007 * effort;
        // Gills and the trailing cheek fins breathe while the face stays steady.
        float gill = region(p, vec2(0.27, 0.58), vec2(0.13, 0.32));
        p.y += sin(phase * 0.65) * gill * 0.009;
        p.y += sin(phase * 1.4 - p.x * 15.0) * region(p, vec2(0.48, 0.75), vec2(0.22, 0.13)) * 0.014;
    } else if (species == 1) {
        float tail = smoothstep(0.60, 0.95, p.x);
        p.x += (p.x - 0.65) * tail * sin(phase) * 0.10 * effort;
        p.y += sin(phase - p.x * 5.0) * tail * 0.028 * effort;
        float fin = region(p, vec2(0.37, 0.73), vec2(0.16, 0.24));
        p.x += sin(phase + 1.2) * fin * 0.022 * effort;
        p.y += cos(phase + 1.2) * fin * 0.015 * effort;
        float dorsal = (1.0 - smoothstep(0.12, 0.38, p.y)) * region(p, vec2(0.46, 0.20), vec2(0.31, 0.32));
        p.x += sin(phase * 0.8 - p.x * 10.0) * dorsal * 0.009;
        p.x += sin(phase * 0.55) * region(p, vec2(0.30, 0.52), vec2(0.13, 0.25)) * 0.006;
    } else {
        float coil = smoothstep(0.53, 0.90, p.y);
        float tail = smoothstep(0.38, 0.95, p.x);
        p.y += sin(phase - p.x * 9.0) * coil * (0.010 + tail * 0.014) * effort;
        p.x += sin(phase * 0.65 - p.y * 5.0) * coil * 0.010 * effort;
        // Hood opens slightly with breathing; hands and scarf trail the torso.
        float hood = region(p, vec2(0.28, 0.20), vec2(0.16, 0.26));
        p.x += (p.x - 0.25) * hood * (sin(phase * 0.55) * 0.045 + tension * 0.05);
        p.y += sin(phase * 0.8 + 1.5) * region(p, vec2(0.35, 0.53), vec2(0.10, 0.15)) * 0.010;
        p.y += sin(phase * 0.8 - p.x * 8.0) * region(p, vec2(0.51, 0.47), vec2(0.24, 0.13)) * 0.018 * effort;
        p.y += sin(phase * 1.8) * region(p, vec2(0.09, 0.27), vec2(0.07, 0.06)) * 0.008;
    }
    // Transparent sampling outside the painting avoids stretched edge pixels.
    vec4 painted = texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)));
    float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
    COLOR = painted * tint;
    COLOR.a *= inside;
}
