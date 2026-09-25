shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

// Drawn on a polygon trailing from the stern (origin) towards -x; a BackBufferCopy
// before it refreshes the screen so this churns the already-drawn water.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float trail_length = 64.0;
uniform float start_width = 14.0;
uniform float end_width = 22.0;
uniform float speed = 12.0;
uniform float distortion = 8.0;
uniform float churn_scale = 0.12;
uniform vec4 foam_color : source_color = vec4(0.85, 0.97, 1.0, 0.3);
uniform float motion : hint_range(0.0, 1.0) = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float t = clamp(-local.x / trail_length, 0.0, 1.0);
	float across = abs(local.y) / mix(start_width, end_width, t);
	float mask = (1.0 - smoothstep(0.3, 1.0, across)) * pow(1.0 - t, 1.5) * motion;

	vec2 p = (local + vec2(TIME * speed, 0.0)) * churn_scale;
	vec2 offset = vec2(value_noise(p), value_noise(p + 17.3)) - 0.5;
	vec3 col = texture(screen_texture, SCREEN_UV + offset * distortion * mask * SCREEN_PIXEL_SIZE).rgb;

	float streak = smoothstep(0.6, 0.85, value_noise(p * vec2(0.4, 2.5) + 5.7));
	COLOR = vec4(mix(col, foam_color.rgb, streak * foam_color.a * mask), 1.0);
}
