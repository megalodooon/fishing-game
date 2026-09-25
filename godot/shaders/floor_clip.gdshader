shader_type canvas_item;

const int MAX_POINTS = 16;

uniform vec2 floor_points[MAX_POINTS];
uniform int floor_count = 0;
uniform sampler2D occluders[3] : filter_nearest;
uniform vec4 occluder_axes[3];
uniform vec2 occluder_origin[3];
uniform int occluder_count = 0;

float covered(sampler2D tex, int i, vec2 p) {
	if (i >= occluder_count) {
		return 0.0;
	}
	vec2 q = occluder_axes[i].xy * p.x + occluder_axes[i].zw * p.y + occluder_origin[i];
	vec2 size = vec2(textureSize(tex, 0));
	if (q.x < 0.0 || q.y < 0.0 || q.x >= size.x || q.y >= size.y) {
		return 0.0;
	}
	return texelFetch(tex, ivec2(q), 0).a;
}

void fragment() {
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE) + 0.5;
	bool inside = false;
	int j = floor_count - 1;
	for (int i = 0; i < floor_count; i++) {
		vec2 a = floor_points[i];
		vec2 b = floor_points[j];
		if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
			inside = !inside;
		}
		j = i;
	}
	float cover = max(covered(occluders[0], 0, p), max(covered(occluders[1], 1, p), covered(occluders[2], 2, p)));
	COLOR.a *= inside && cover <= 0.0 ? 1.0 : 0.0;
}
