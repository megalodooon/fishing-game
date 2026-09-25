shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

// CanvasGroup material: the child particles only paint foam density (alpha);
// this turns it into a bubbly sheet that goes from solid to lace to nothing.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 foam_color : source_color = vec4(0.93, 0.98, 1.0, 0.85);
uniform vec4 shade_color : source_color = vec4(0.62, 0.8, 0.88, 1.0);
uniform float bubble_size = 1.6;
uniform float stretch = 1.8; // bubbles drawn out along the flow
uniform float speed = 10.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.3;
uniform float softness = 0.12;
uniform float holes : hint_range(0.0, 1.0) = 0.55;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float density = textureLod(screen_texture, SCREEN_UV, 0.0).r;
	if (density * 1.25 <= threshold) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = (world + vec2(TIME * speed, 0.0)) / bubble_size;
		p.x /= stretch;
		p += vec2(value_noise(p * 0.5), value_noise(p * 0.5 + 9.1)) - 0.5;
		float rim = smoothstep(0.15, 0.55, min(voronoi(p, TIME), voronoi(p * 0.6 + 7.3, TIME * 0.7) + 0.1));
		density *= mix(0.75, 1.25, value_noise(p * 0.2));
		float foam = smoothstep(threshold, threshold + softness, density - (1.0 - rim) * holes);
		COLOR = vec4(mix(shade_color.rgb, foam_color.rgb, rim), foam * foam_color.a);
	}
}
