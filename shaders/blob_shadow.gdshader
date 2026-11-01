shader_type spatial;
// Soft round contact shadow on a flat quad, in place of real-time shadows.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 shadow_color : source_color = vec4(0.478, 0.322, 0.2, 0.22);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * (1.0 - smoothstep(0.45, 1.0, d));
}
