shader_type canvas_item;

#include "res://rods/effects/occluders.gdshaderinc"

uniform vec2 grip = vec2(2.0, 13.0);
uniform vec2 tip = vec2(14.5, 0.5);
uniform float bend = 0.0;

varying vec2 world;
varying vec4 modulate;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec2 uv = rod_bend(UV / TEXTURE_PIXEL_SIZE, grip, tip, bend) * TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, uv);
	color.a *= step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	color.a *= 1.0 - occlusion(world, TIME);
	COLOR = color * modulate;
}
