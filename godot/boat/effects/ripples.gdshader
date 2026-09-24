shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 crest_color : source_color = vec4(0.85, 0.97, 1.0, 0.55);
uniform vec4 trough_color : source_color = vec4(0.0, 0.08, 0.2, 0.2);
uniform float spacing = 3.5;
uniform float speed = 0.5;
uniform float crest_width = 0.45;
uniform float trough_width = 0.8;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;
uniform float start_distance = 0.3;
uniform float reach = 11.0;
uniform float wobble = 0.8;
uniform float breakup : hint_range(0.0, 1.0) = 0.35;
// Boat speed relative to ripple speed; the bow faces +x. Water streaming past
// squeezes ripples into a short bow wave and stretches them out behind.
uniform float drift : hint_range(0.0, 0.9) = 0.6;

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	vec2 e = TEXTURE_PIXEL_SIZE;
	float d = texture(TEXTURE, UV).r;
	float ahead = normalize(vec2(
		texture(TEXTURE, UV + vec2(e.x, 0.0)).r - texture(TEXTURE, UV - vec2(e.x, 0.0)).r,
		texture(TEXTURE, UV + vec2(0.0, e.y)).r - texture(TEXTURE, UV - vec2(0.0, e.y)).r) + 1e-6).x;
	d += (value_noise(p * 0.08 + TIME * 0.25) - 0.5) * wobble;
	d /= 1.0 - drift * ahead;

	float phase = d / spacing - TIME * speed;
	float offset = (fract(phase + 0.5) - 0.5) * spacing;
	float distance_fade = clamp(1.0 - d / reach, 0.0, 1.0);
	float width = crest_width * mix(0.5, 1.0, distance_fade);
	float aa = fwidth(d);

	float crest = 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, abs(offset));
	crest = max(crest, exp(-offset * offset / (width * width * 4.0)) * glow_strength);
	float trough_offset = offset - width - trough_width * 0.5;
	float trough = exp(-trough_offset * trough_offset / (trough_width * trough_width * 0.5));

	float mask = smoothstep(breakup - 0.15, breakup + 0.15, value_noise(p / 10.0 + floor(phase + 0.5) * 13.7));
	float fade = smoothstep(start_distance, start_distance + 1.5, d) * pow(distance_fade, 1.5) * mask;

	float crest_alpha = crest * crest_color.a * fade;
	float trough_alpha = trough * trough_color.a * fade;
	float alpha = crest_alpha + trough_alpha * (1.0 - crest_alpha);
	vec3 color = (crest_color.rgb * crest_alpha + trough_color.rgb * trough_alpha * (1.0 - crest_alpha)) / max(alpha, 0.0001);
	COLOR = vec4(color, alpha);
}
