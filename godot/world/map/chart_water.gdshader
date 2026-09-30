shader_type canvas_item;

// The sea on the chart: the same look as the ocean's water (shallow to deep
// color, gentle waves, caustics in the shallows) but cheap enough for a menu.
// The chart bakes the colors into `field` once: rgb is the water's color
// there (shallow near islands, deep far out, tinted by nearby places), a is
// how much caustic light the spot gets.

uniform sampler2D field : filter_linear, repeat_disable;
// Chart pixels covered by the field texture.
uniform vec2 field_size = vec2(1.0);
// Chart pixel at the rect's top left corner.
uniform vec2 origin = vec2(0.0);

group_uniforms waves;
uniform float wave_scale = 20.0;
uniform float wave_strength = 0.8;
uniform float wave_speed = 0.8;
uniform float swell = 0.05;

group_uniforms caustics;
uniform vec4 caustic_color : source_color = vec4(0.8, 1.0, 1.0, 1.0);
uniform float caustic_amount : hint_range(0.0, 8.0) = 1.2;
uniform float caustic_cell_size : hint_range(1.0, 64.0, 0.5) = 9.0;
uniform float caustic_sharpness : hint_range(1.0, 8.0) = 3.5;

group_uniforms chart;
// Faint lines of latitude and longitude, every this many chart pixels.
uniform float grid_step = 48.0;
uniform vec4 grid_color : source_color = vec4(0.9, 0.97, 1.0, 0.07);
// Darkens the chart's edges.
uniform float vignette : hint_range(0.0, 1.0) = 0.22;

varying vec2 chart_pos;

vec2 cell_offset(vec2 cell) {
	vec2 p = vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float cell_voronoi(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 diff = o + cell_offset(cell + o) - f;
			d = min(d, dot(diff, diff));
		}
	}
	return sqrt(d);
}

void vertex() {
	chart_pos = VERTEX + origin;
}

void fragment() {
	vec2 w = chart_pos / wave_scale;
	float wt = TIME * wave_speed;
	vec2 wave = 0.5 * vec2(
		sin(w.y * 6.28 + wt) + sin((w.x + w.y) * 4.1 - wt * 1.3),
		cos(w.x * 6.28 + wt * 0.9) + cos((w.x - w.y) * 3.7 + wt * 1.1));
	vec2 p = chart_pos + wave * wave_strength;

	vec4 water = texture(field, p / field_size);
	vec3 col = water.rgb * (1.0 + swell * sin(p.x * 0.07 + p.y * 0.05 + wt * 0.5) * sin(p.y * 0.11 - wt * 0.3));

	if (water.a > 0.0) {
		vec2 c = p / caustic_cell_size;
		float caustic = min(cell_voronoi(c), cell_voronoi(c * 0.8 + vec2(13.7, 7.3)));
		col += caustic_color.rgb * pow(caustic, caustic_sharpness) * caustic_amount * water.a;
	}

	vec2 line = abs(fract(chart_pos / grid_step + 0.5) - 0.5) * grid_step;
	vec2 thin = fwidth(chart_pos);
	float grid = max(1.0 - smoothstep(0.0, thin.x, line.x), 1.0 - smoothstep(0.0, thin.y, line.y));
	col = mix(col, grid_color.rgb, grid * grid_color.a);

	vec2 edge = min(UV, 1.0 - UV) * vec2(12.0, 8.0);
	col *= 1.0 - vignette * (1.0 - smoothstep(0.0, 1.0, min(edge.x, edge.y)));

	COLOR = vec4(col, 1.0);
}
