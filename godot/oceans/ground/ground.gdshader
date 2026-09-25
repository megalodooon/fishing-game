shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

uniform float scroll = 0.0;
uniform vec2 seed_offset = vec2(0.0);

group_uniforms depth;
uniform float depth_scale = 90.0;
uniform float depth_contrast = 1.4;
uniform float depth_bias = 0.0;

group_uniforms colors;
uniform sampler2D ground_colors : source_color, filter_linear, repeat_disable;
uniform int color_bands = 6;
uniform float relief = 0.6;
uniform vec2 light_direction = vec2(-0.7, -0.7);
uniform float grain = 0.04;
uniform float speckle_density = 0.03;
uniform float speckle_strength = 0.12;
uniform vec4 fog_color : source_color = vec4(0.1, 0.2, 0.28, 1.0);
uniform float fog_amount = 0.3;

group_uniforms ripples;
uniform float ripple_scale = 5.0;
uniform float ripple_angle = 0.4;
uniform float ripple_strength = 0.06;
uniform float ripple_warp = 1.5;
uniform float ripple_max_depth = 0.45;

group_uniforms grass;
uniform sampler2D grass_colors : source_color, filter_linear, repeat_disable;
uniform float grass_cell = 12.0;
uniform float grass_density = 0.3;
uniform vec2 grass_depth = vec2(0.2, 0.65);
uniform float grass_softness = 0.08;
uniform vec2 grass_blades = vec2(3.0, 6.0);
uniform vec2 grass_height = vec2(2.0, 4.0);
uniform float grass_spread = 3.0;

varying vec2 ground_pos;

void vertex() {
	ground_pos = VERTEX + vec2(scroll, 0.0);
}

float ground_depth(vec2 p) {
	vec2 q = p / depth_scale + seed_offset;
	float n = value_noise(q) * 0.6 + value_noise(q * 2.13 + 7.7) * 0.3 + value_noise(q * 4.7 + 3.1) * 0.1;
	return clamp((n - 0.5) * depth_contrast + 0.5 + depth_bias, 0.0, 1.0);
}

vec4 grass_at(vec2 px) {
	vec2 cell = floor(px / grass_cell);
	vec2 key = cell + seed_offset;
	vec2 center = cell * grass_cell + vec2(
		floor(mix(grass_spread + 1.0, grass_cell - grass_spread - 2.0, hash(key + vec2(5.0, 91.0)))),
		floor(mix(grass_height.y + 1.0, grass_cell - 2.0, hash(key + vec2(47.0, 13.0)))));
	float d = ground_depth(center);
	float mask = smoothstep(grass_depth.x - grass_softness, grass_depth.x + grass_softness, d);
	mask *= 1.0 - smoothstep(grass_depth.y - grass_softness, grass_depth.y + grass_softness, d);
	if (hash(key + vec2(311.0, 173.0)) >= grass_density * mask) {
		return vec4(0.0);
	}
	int blades = int(floor(mix(grass_blades.x, grass_blades.y + 0.999, hash(key + vec2(7.0, 3.0)))));
	for (int i = 0; i < 16; i++) {
		if (i >= blades) {
			break;
		}
		vec2 k = key + vec2(float(i) * 13.0 + 101.0, float(i) * 29.0 + 57.0);
		float bx = center.x + floor((hash(k) - 0.5) * 2.0 * grass_spread + 0.5);
		float by = center.y + floor(hash(k + vec2(3.0, 0.0)) * 2.0);
		float h = floor(mix(grass_height.x, grass_height.y + 0.999, hash(k + vec2(0.0, 5.0))));
		float lean = (hash(k + vec2(9.0, 9.0)) - 0.5) * 2.0;
		float up = by - px.y;
		if (up >= 0.0 && up < h) {
			float along = up / max(h - 1.0, 1.0);
			if (px.x == bx + floor(lean * along + 0.5)) {
				return vec4(texture(grass_colors, vec2(along, 0.5)).rgb, 1.0);
			}
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 px = floor(ground_pos);
	vec2 t = px + 0.5;
	float d = ground_depth(t);
	vec2 slope = vec2(ground_depth(t + vec2(1.0, 0.0)) - d, ground_depth(t + vec2(0.0, 1.0)) - d) * depth_scale;
	float shade = 1.0 + relief * dot(slope, normalize(light_direction));

	float band = color_bands > 0 ? (floor(d * float(color_bands)) + 0.5) / float(color_bands) : d;
	vec3 col = texture(ground_colors, vec2(band, 0.5)).rgb * clamp(shade, 0.4, 1.6);

	vec2 dir = vec2(cos(ripple_angle), sin(ripple_angle));
	float r = sin((dot(t, dir) / ripple_scale + value_noise(t / 12.0 + seed_offset) * ripple_warp) * TAU);
	float ripple_mask = (1.0 - smoothstep(ripple_max_depth - 0.1, ripple_max_depth + 0.1, d)) * ripple_strength;
	col *= 1.0 + ripple_mask * (step(0.6, r) - step(r, -0.6) * 0.5);

	col *= 1.0 + (hash(px + seed_offset + vec2(1000.0, 0.0)) - 0.5) * 2.0 * grain;
	float speck = hash(px + seed_offset + vec2(0.0, 1000.0));
	col *= 1.0 - speckle_strength * step(speck, speckle_density) + speckle_strength * step(1.0 - speckle_density * 0.5, speck);

	vec4 blade = grass_at(px);
	col = mix(col, blade.rgb, blade.a);
	col = mix(col, fog_color.rgb, d * fog_amount);
	COLOR = vec4(col, 1.0);
}
