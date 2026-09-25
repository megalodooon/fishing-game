vec2 sail_wind(vec2 p, vec4 sail_rect, float anchor_inset, float strength, float speed, float ripple_frequency, float time) {
	float v = clamp((floor(p.y) + 0.5 - sail_rect.y) / sail_rect.w, 0.0, 1.0);
	float stretch = clamp((p.x - sail_rect.x - anchor_inset) / (sail_rect.z - anchor_inset), 0.0, 1.0);
	float wave = 0.6 * sin(time * speed - v * ripple_frequency * TAU) + 0.4;
	p.x -= strength * sin(v * PI) * stretch * wave;
	return p;
}
