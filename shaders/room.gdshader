shader_type spatial;
// Room surfaces: soft half-lambert light, plus an optional pattern drawn in UV
// space: 0 plain, 1 staggered polka dots, 2 floor planks, 3 rug rings.
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform vec4 accent_color_2 : source_color = vec4(1.0);
uniform int pattern = 0;
// Surface size in metres, so dots stay round on any plane.
uniform vec2 size = vec2(1.0);
uniform float spacing = 0.22;
// Dot radius as a fraction of one cell.
uniform float dot_radius = 0.16;
// Darkens toward UV.y = 1 (wall bottoms) for a cheap contact shade.
uniform float floor_shade = 0.0;

float aa_step(float edge, float x) {
	float w = fwidth(x) * 0.75;
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	vec3 col = base_color.rgb;
	vec2 p = UV * size;
	if (pattern == 1) {
		vec2 g = p / spacing;
		g.x += mod(floor(g.y), 2.0) * 0.5;
		float d = length(fract(g) - 0.5);
		col = mix(col, accent_color.rgb, 1.0 - aa_step(dot_radius, d));
	} else if (pattern == 2) {
		float plank = fract(p.x / spacing);
		float row = floor(p.x / spacing);
		float seam = 1.0 - aa_step(0.03, min(plank, 1.0 - plank));
		float tone = fract(sin(row * 12.9898) * 43758.5453) * 0.05;
		col = mix(col * (1.0 - tone), accent_color.rgb, seam * 0.6);
	} else if (pattern == 3) {
		float r = length(UV - 0.5) * 2.0;
		float ring = fract(r * 4.0);
		float band = aa_step(0.5, ring);
		col = mix(base_color.rgb, accent_color.rgb, band);
		col = mix(col, accent_color_2.rgb, aa_step(0.86, r));
	}
	col *= 1.0 - floor_shade * smoothstep(0.55, 1.0, UV.y);
	ALBEDO = col;
}

void light() {
	float wrap = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * wrap / PI;
}
