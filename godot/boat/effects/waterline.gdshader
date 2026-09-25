shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

const int MAX_COLUMNS = 128;

uniform float edges[MAX_COLUMNS];
uniform vec2 bob = vec2(0.0);
uniform float motion : hint_range(0.0, 1.0) = 0.0;
uniform float flow = 0.0;
uniform float depth = 2.5;
uniform float wave_height = 0.7;
uniform float wave_length = 16.0;
uniform float wave_speed = 1.6;
uniform float flow_speed = 4.0;
uniform bool underwater = false;
uniform vec4 line_color : source_color = vec4(0.85, 0.97, 1.0, 0.75);
uniform float line_width = 0.6;
uniform float end_rise = 5.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float edge_at(float x) {
	float fx = x - 0.5;
	int c0 = clamp(int(floor(fx)), 0, MAX_COLUMNS - 1);
	int c1 = min(c0 + 1, MAX_COLUMNS - 1);
	float e0 = edges[c0] > 0.0 ? edges[c0] : edges[c1];
	float e1 = edges[c1] > 0.0 ? edges[c1] : e0;
	return mix(e0, e1, fract(fx));
}

float wave(float x) {
	float t = TIME * wave_speed;
	float travel = flow * flow_speed / wave_length;
	float w = sin((x / wave_length + travel) * TAU - t) * 0.55;
	w += sin((x / (wave_length * 0.55) + travel) * TAU + t * 1.3) * 0.3;
	w += (value_noise(vec2(x * 0.2 + flow * flow_speed * 0.2, TIME * 0.6)) - 0.5) * 0.6;
	return w * wave_height * (1.0 + motion * 0.5);
}

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float center = 0.5 / TEXTURE_PIXEL_SIZE.x;
	float aa = max(fwidth(p.y), 0.05);
	float rest = edge_at(p.x) - depth - bob.x - (p.x - center) * bob.y;
	float highest = rest - 1.15 * abs(wave_height) * (1.0 + motion * 0.5) - line_width * 0.5 - aa - 0.01 - end_rise;
	vec4 hull = texture(TEXTURE, UV) * modulate;
	if (p.y < highest) {
		COLOR = underwater ? vec4(0.0) : hull;
	} else {
		float waterline = rest + wave(p.x);
		float below = smoothstep(waterline - aa, waterline + aa, p.y);
		if (underwater) {
			COLOR = vec4(hull.rgb, hull.a * below);
		} else {
			float alpha = hull.a * (1.0 - below);
			float slope = edge_at(p.x + 0.5) - edge_at(p.x - 0.5) + wave(p.x + 0.5) - wave(p.x - 0.5) - bob.y;
			float line = 1.0 - smoothstep(line_width * 0.5, line_width * 0.5 + aa, abs(p.y - waterline) * inversesqrt(1.0 + slope * slope));
			float strength = line;
			if (hull.a <= 0.5) {
				float near = max(texture(TEXTURE, (p + vec2(line_width, 0.0)) * TEXTURE_PIXEL_SIZE).a, texture(TEXTURE, (p - vec2(line_width, 0.0)) * TEXTURE_PIXEL_SIZE).a);
				float up = waterline - p.y;
				float hug = step(0.5, near) * smoothstep(-aa, aa, up) * (1.0 - smoothstep(0.0, end_rise, up));
				float column = step(0.5, edges[clamp(int(floor(p.x)), 0, MAX_COLUMNS - 1)]);
				strength = max(hug, line * column);
			}
			float over = strength * line_color.a;
			float total = over + alpha * (1.0 - over);
			COLOR = vec4((line_color.rgb * over + hull.rgb * alpha * (1.0 - over)) / max(total, 0.0001), total);
		}
	}
}