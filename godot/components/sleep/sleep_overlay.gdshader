shader_type canvas_item;

// Darkens the screen edges when the player gets drowsy and closes curved
// eyelids from the top and bottom when they fall asleep. No screen reads.

uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float lids : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.5) = 0.12;
uniform vec4 shade : source_color = vec4(0.01, 0.02, 0.05, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p * vec2(1.0, 0.85));
	float dark = vignette * smoothstep(0.3, 1.45, edge);
	float reach = mix(1.6, -0.2, lids) * (1.0 - 0.3 * p.x * p.x);
	float closed = smoothstep(reach - softness, reach + softness * 0.2, abs(p.y));
	COLOR = vec4(shade.rgb, max(dark, closed) * shade.a);
}
