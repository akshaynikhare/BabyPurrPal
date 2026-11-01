shader_type spatial;
// Window view: vertical sky gradient, a sun or moon disc, and twinkling stars at night.
render_mode unshaded, specular_disabled, shadows_disabled, fog_disabled;

uniform vec4 top_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 orb_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec2 orb_pos = vec2(0.7, 0.3);
uniform float orb_radius = 0.12;
uniform float stars = 0.0;
// Window aspect (w / h), keeps the orb round.
uniform float aspect = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	vec2 q = vec2(UV.x * aspect, UV.y);
	vec2 cell = floor(q * 9.0);
	vec2 f = fract(q * 9.0) - 0.5;
	float h = hash(cell);
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + h * 40.0);
	float star = (1.0 - smoothstep(0.03, 0.09, length(f - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6)));
	col = mix(col, vec3(1.0, 0.97, 0.85), star * step(0.55, h) * stars * twinkle);
	float d = length((q - vec2(orb_pos.x * aspect, orb_pos.y)));
	float w = fwidth(d);
	col = mix(col, orb_color.rgb, 1.0 - smoothstep(orb_radius - w, orb_radius + w, d));
	col = mix(col, orb_color.rgb, (1.0 - smoothstep(orb_radius, orb_radius * 2.4, d)) * 0.25 * orb_color.a);
	ALBEDO = col;
}
