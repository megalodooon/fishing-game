shader_type canvas_item;

#include "res://rods/effects/occluders.gdshaderinc"

uniform float waterline = 5.0;
uniform float submerge = 0.0;
uniform vec4 water_color : source_color = vec4(0.1, 0.42, 0.55, 1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.55;
uniform float fade : hint_range(0.0, 1.0) = 0.5;
uniform float softness = 0.35;
uniform float wobble = 0.25;
uniform vec4 highlight_color : source_color = vec4(0.9, 1.0, 1.0, 0.75);

varying vec2 world;
varying vec4 modulate;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	float row = UV.y / TEXTURE_PIXEL_SIZE.y;
	float below = smoothstep(waterline - softness, waterline + softness, row) * submerge;
	vec2 uv = UV + vec2(sin(row * 2.5 + TIME * 4.0) * wobble * below * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 color = texture(TEXTURE, uv) * modulate;
	color.rgb = mix(color.rgb, water_color.rgb, tint * below);
	color.a *= 1.0 - fade * below;
	float edge = (1.0 - smoothstep(0.0, 0.45, abs(row - waterline))) * submerge * color.a;
	color.rgb = mix(color.rgb, highlight_color.rgb, edge * highlight_color.a);
	color.a *= 1.0 - occlusion(world, TIME);
	COLOR = color;
}
