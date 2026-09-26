shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms colors;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.62, 0.78, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.17, 0.36, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.8, 1.0, 1.0, 1.0);

group_uniforms waves;
uniform float wave_scale = 20.0;
uniform float wave_strength = 0.8;
uniform float wave_speed = 0.8;

group_uniforms underwater;
uniform float clarity : hint_range(0.0, 1.0) = 0.55;
uniform float refraction_strength = 2.5;

group_uniforms caustics;
uniform float caustic_amount : hint_range(0.0, 8.0) = 2.5;
uniform float caustic_cell_size : hint_range(1.0, 64.0, 0.5) = 9.0;
uniform float caustic_sharpness : hint_range(1.0, 8.0) = 3.5;

group_uniforms flow;
uniform vec2 scroll = vec2(0.0);
uniform sampler2D fields : filter_linear, repeat_disable;
uniform vec2 fields_origin = vec2(0.0);
uniform vec2 fields_size = vec2(1.0);
uniform sampler2D cells_a : filter_nearest, repeat_disable;
uniform sampler2D cells_b : filter_nearest, repeat_disable;
uniform vec2 cells_a_origin = vec2(0.0);
uniform vec2 cells_b_origin = vec2(0.0);

varying vec2 world_pos;

float cell_voronoi(vec2 p, sampler2D cells, vec2 origin) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 diff = o + texelFetch(cells, ivec2(cell + o - origin), 0).rg - f;
			d = min(d, dot(diff, diff));
		}
	}
	return sqrt(d);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + scroll;
}

void fragment() {
	vec2 w = world_pos / wave_scale;
	float wt = TIME * wave_speed;
	vec2 wave = 0.5 * vec2(
		sin(w.y * 6.28 + wt) + sin((w.x + w.y) * 4.1 - wt * 1.3),
		cos(w.x * 6.28 + wt * 0.9) + cos((w.x - w.y) * 3.7 + wt * 1.1));
	vec2 p = world_pos + wave * wave_strength;

	vec2 field = texture(fields, (p - fields_origin) / fields_size).rg;
	float depth = field.r;
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, depth);

	vec3 below = texture(screen_texture, SCREEN_UV + wave * refraction_strength * SCREEN_PIXEL_SIZE).rgb;
	vec3 col = mix(water, below, clarity * (1.0 - depth * 0.5));

	float coverage = field.g;
	if (coverage > 0.0) {
		vec2 c = p / caustic_cell_size;
		float caustic = min(cell_voronoi(c, cells_a, cells_a_origin), cell_voronoi(c * 0.8 + vec2(13.7, 7.3), cells_b, cells_b_origin));
		col += caustic_color.rgb * pow(caustic, caustic_sharpness) * caustic_amount * coverage * (1.0 - depth * 0.5);
	}

	COLOR = vec4(col, texture(TEXTURE, UV).a * COLOR.a);
}
