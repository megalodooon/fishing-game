shader_type canvas_item;

#include "res://boat/effects/sail_wind.gdshaderinc"

uniform vec4 sail_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float anchor_inset = 1.0;
uniform float strength : hint_range(0.0, 4.0) = 2.5;
uniform float speed = 1.6;
uniform float ripple_frequency = 0.6;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 p = sail_wind(UV / TEXTURE_PIXEL_SIZE, sail_rect, anchor_inset, strength, speed, ripple_frequency, TIME);
	COLOR = texture(TEXTURE, p * TEXTURE_PIXEL_SIZE) * modulate;
}
