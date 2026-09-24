shader_type canvas_item;

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
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float v = clamp((floor(p.y) + 0.5 - sail_rect.y) / sail_rect.w, 0.0, 1.0);
	float stretch = clamp((p.x - sail_rect.x - anchor_inset) / (sail_rect.z - anchor_inset), 0.0, 1.0);
	float wave = 0.6 * sin(TIME * speed - v * ripple_frequency * TAU) + 0.4;
	p.x -= strength * sin(v * PI) * stretch * wave;
	COLOR = texture(TEXTURE, p * TEXTURE_PIXEL_SIZE) * modulate;
}
