shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

const int MAX_RINGS = 24;

uniform sampler2D distance_field : repeat_disable, filter_linear;
uniform vec4 rings[MAX_RINGS];
uniform float seeds[MAX_RINGS];
uniform int ring_count = 0;
uniform vec2 hull_center = vec2(0.5, 20.5);
uniform vec2 hull_radii = vec2(48.0, 20.0);
uniform float round_distance = 8.0;
uniform vec4 crest_color : source_color = vec4(0.85, 0.97, 1.0, 0.3);
uniform vec4 trough_color : source_color = vec4(0.0, 0.08, 0.2, 0.1);
uniform float crest_width = 0.45;
uniform float trough_width = 0.8;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;
uniform float start_distance = 0.3;
uniform float wobble = 1.2;
uniform float breakup : hint_range(0.0, 1.0) = 0.35;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float ellipse_distance(vec2 p) {
	float k0 = length(p / hull_radii);
	float k1 = length(p / (hull_radii * hull_radii));
	return k0 * (k0 - 1.0) / max(k1, 1e-4);
}

void fragment() {
	vec2 field_size = vec2(textureSize(distance_field, 0));
	float reach = 2.0 * crest_width + 2.5 * trough_width + 0.5 * abs(wobble) + 1.0;
	float crest = 0.0;
	float trough = 0.0;
	for (int i = 0; i < ring_count; i++) {
		vec2 p = local - rings[i].xy;
		float d = texture(distance_field, p / field_size + 0.5).r;
		float shape = mix(d, ellipse_distance(p - hull_center), smoothstep(0.0, round_distance, rings[i].z));
		float base = shape - rings[i].z;
		float aa = fwidth(base);
		if (abs(base) > reach) {
			continue;
		}
		float offset = base + (value_noise(p * 0.08 + seeds[i] + TIME * 0.25) - 0.5) * wobble;
		float c = 1.0 - smoothstep(crest_width * 0.5, crest_width * 0.5 + aa, abs(offset));
		c = max(c, exp(-offset * offset / (crest_width * crest_width * 4.0)) * glow_strength);
		float t = offset - crest_width - trough_width * 0.5;
		t = exp(-t * t / (trough_width * trough_width * 0.5));
		float mask = smoothstep(breakup - 0.15, breakup + 0.15, value_noise(p / 8.0 + seeds[i] * 1.7));
		mask *= smoothstep(start_distance, start_distance + 1.5, d) * rings[i].w;
		crest = max(crest, c * mask);
		trough = max(trough, t * mask);
	}
	float crest_alpha = crest * crest_color.a;
	float trough_alpha = trough * trough_color.a;
	float alpha = crest_alpha + trough_alpha * (1.0 - crest_alpha);
	vec3 color = (crest_color.rgb * crest_alpha + trough_color.rgb * trough_alpha * (1.0 - crest_alpha)) / max(alpha, 0.0001);
	COLOR = vec4(color, alpha);
}
