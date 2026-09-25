shader_type canvas_item;
render_mode blend_mul, unshaded;

const int MAX_LIGHTS = 16;

uniform vec3 ambient = vec3(1.0);
uniform vec4 lights[MAX_LIGHTS];
uniform vec4 light_colors[MAX_LIGHTS];
uniform int light_count = 0;

varying vec2 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	vec3 light = ambient;
	for (int i = 0; i < light_count; i++) {
		vec2 offset = (position - lights[i].xy) / lights[i].zw;
		float falloff = max(1.0 - dot(offset, offset), 0.0);
		light += light_colors[i].rgb * pow(falloff, light_colors[i].a);
	}
	COLOR = vec4(light, 1.0);
}
