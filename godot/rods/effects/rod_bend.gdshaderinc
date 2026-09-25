vec2 rod_bend(vec2 pixel, vec2 grip, vec2 tip, float bend) {
	vec2 axis = tip - grip;
	float len = length(axis);
	axis /= len;
	float t = clamp(dot(pixel - grip, axis) / len, 0.0, 1.0);
	return pixel - vec2(-axis.y, axis.x) * bend * t * t;
}
