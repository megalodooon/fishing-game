shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

uniform vec2 cells_origin = vec2(0.0);
uniform float caustic_speed = 0.7;
uniform float speed_scale = 1.0;
// Still water (islands) is frozen at still_time instead of moving with TIME.
uniform bool still = false;
uniform float still_time = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 cell = cells_origin + floor(local);
	COLOR = vec4(0.5 + 0.5 * sin((still ? still_time : TIME) * caustic_speed * speed_scale + 6.2831 * hash2(cell)), 0.0, 1.0);
}
