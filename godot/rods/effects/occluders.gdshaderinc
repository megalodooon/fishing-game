#include "res://boat/effects/sail_wind.gdshaderinc"
#include "res://rods/effects/rod_bend.gdshaderinc"

uniform bool occlude = false;
uniform sampler2D occluders[3] : filter_nearest;
uniform vec4 occluder_axes[3];
uniform vec2 occluder_origin[3];
uniform int occluder_mode[3];
uniform vec4 occluder_a[3];
uniform vec4 occluder_b[3];
uniform float rod_bend_amount = 0.0;
uniform float occluder_strength = 1.0;

float cover(sampler2D tex, int i, vec2 point, float time) {
	if (occluder_mode[i] == 0) {
		return 0.0;
	}
	vec2 p = occluder_axes[i].xy * point.x + occluder_axes[i].zw * point.y + occluder_origin[i];
	if (occluder_mode[i] == 2) {
		p = sail_wind(p, occluder_a[i], occluder_b[i].x, occluder_b[i].y, occluder_b[i].z, occluder_b[i].w, time);
	} else if (occluder_mode[i] == 3) {
		p = rod_bend(p, occluder_a[i].xy, occluder_a[i].zw, rod_bend_amount);
	}
	vec2 size = vec2(textureSize(tex, 0));
	if (p.x < 0.0 || p.y < 0.0 || p.x >= size.x || p.y >= size.y) {
		return 0.0;
	}
	return texture(tex, p / size).a;
}

float occlusion(vec2 point, float time) {
	float covered = occlude || occluder_mode[2] == 3 ? cover(occluders[2], 2, point, time) : 0.0;
	if (occlude) {
		covered = max(covered, max(cover(occluders[0], 0, point, time), cover(occluders[1], 1, point, time)) * occluder_strength);
	}
	return covered;
}
