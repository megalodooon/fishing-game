shader_type canvas_item;

#include "res://rods/effects/occluders.gdshaderinc"

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR.a *= 1.0 - occlusion(world, TIME);
}
