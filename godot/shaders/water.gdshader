shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms colors;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.62, 0.78, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.17, 0.36, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.8, 1.0, 1.0, 1.0);

group_uniforms depth;
uniform float depth_scale = 64.0;
uniform float depth_contrast : hint_range(0.0, 4.0) = 1.6;
uniform float depth_speed = 0.01;

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
uniform float caustic_speed = 0.7;
uniform float caustic_sharpness : hint_range(1.0, 8.0) = 3.5;
uniform float caustic_coverage : hint_range(0.0, 100.0, 1.0) = 100.0;
uniform float caustic_patch_size : hint_range(4.0, 256.0, 1.0) = 48.0;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

// Distance to the nearest moving cell point; bright at cell borders.
float voronoi(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 diff = o + 0.5 + 0.5 * sin(t + 6.2831 * hash2(cell + o)) - f;
			d = min(d, dot(diff, diff));
		}
	}
	return sqrt(d);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 w = world_pos / wave_scale;
	float wt = TIME * wave_speed;
	vec2 wave = 0.5 * vec2(
		sin(w.y * 6.28 + wt) + sin((w.x + w.y) * 4.1 - wt * 1.3),
		cos(w.x * 6.28 + wt * 0.9) + cos((w.x - w.y) * 3.7 + wt * 1.1));
	vec2 p = world_pos + wave * wave_strength;

	vec2 q = p / depth_scale + TIME * depth_speed;
	float depth = value_noise(q) * 0.65 + value_noise(q * 2.3 + 5.1) * 0.35;
	depth = clamp((depth - 0.5) * depth_contrast + 0.5, 0.0, 1.0);
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, depth);

	vec3 below = texture(screen_texture, SCREEN_UV + wave * refraction_strength * SCREEN_PIXEL_SIZE).rgb;
	vec3 col = mix(water, below, clarity * (1.0 - depth * 0.5));

	float edge = (1.0 - caustic_coverage * 0.01) * 1.3 - 0.3;
	float coverage = smoothstep(edge, edge + 0.3, value_noise(p / caustic_patch_size + 31.7));
	if (coverage > 0.0) {
		vec2 c = p / caustic_cell_size;
		float ct = TIME * caustic_speed;
		float caustic = min(voronoi(c, ct), voronoi(c * 0.8 + vec2(13.7, 7.3), ct * 1.3));
		col += caustic_color.rgb * pow(caustic, caustic_sharpness) * caustic_amount * coverage * (1.0 - depth * 0.5);
	}

	COLOR = vec4(col, texture(TEXTURE, UV).a * COLOR.a);
}
