// Integer hash of a lattice point: bit-exact at any magnitude. A fract(sin()) hash
// lets neighbouring cells disagree on a shared corner, which shows up as hard seams.
float hash(vec2 p) {
	uvec2 x = uvec2(ivec2(p));
	uvec2 q = 1103515245u * ((x >> 1u) ^ x.yx);
	uint n = 1103515245u * (q.x ^ (q.y >> 3u));
	return float(n) / 4294967295.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(57.0, 113.0)));
}

// Distance to the nearest moving cell point; bright at cell borders.
float voronoi(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 diff = o + 0.5 + 0.5 * sin(t + 6.2831 * hash2(cell + o)) - f;
			d = min(d, dot(diff, diff));
		}
	}
	return sqrt(d);
}
