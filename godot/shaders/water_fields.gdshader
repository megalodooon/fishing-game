shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

uniform vec2 fields_origin = vec2(0.0);
uniform float depth_scale = 64.0;
uniform float depth_contrast = 1.6;
uniform float depth_speed = 0.01;
uniform float caustic_coverage = 100.0;
uniform float caustic_patch_size = 48.0;

varying vec2 world_pos;

float evolving_noise(vec2 p, float t) {
	float i = floor(t);
	return mix(value_noise(p + i * 17.31), value_noise(p + (i + 1.0) * 17.31), smoothstep(0.0, 1.0, fract(t)));
}

void vertex() {
	world_pos = VERTEX + fields_origin;
}

void fragment() {
	vec2 q = world_pos / depth_scale;
	float dt = TIME * depth_speed;
	float depth = evolving_noise(q, dt) * 0.65 + evolving_noise(q * 2.3 + 5.1, dt * 1.3 + 0.5) * 0.35;
	depth = clamp((depth - 0.5) * depth_contrast + 0.5, 0.0, 1.0);
	float edge = (1.0 - caustic_coverage * 0.01) * 1.3 - 0.3;
	float coverage = smoothstep(edge, edge + 0.3, value_noise(world_pos / caustic_patch_size + 31.7));
	COLOR = vec4(depth, coverage, 0.0, 1.0);
}
