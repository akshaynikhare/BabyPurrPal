shader_type spatial;
// Flat-albedo cel shading: three stepped diffuse bands from the one directional
// light, ambient fills the shadow band, plus a soft view rim.
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
// 0 = fully lit by the bands, 1 = ignores light (eye highlights).
uniform float self_light : hint_range(0.0, 1.0) = 0.0;
uniform float band_soft : hint_range(0.001, 0.2) = 0.04;
uniform float mid_band : hint_range(0.0, 1.0) = 0.45;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
// Metres toward the camera along the view ray: lets a thin inner shell (the
// tongue) win the depth test without changing its outline on screen.
uniform float view_bias = 0.0;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz -= normalize(view_pos.xyz) * view_bias;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = albedo.rgb * (1.0 - self_light);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = albedo.rgb * self_light + rim_color.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-band_soft, band_soft, ndl) * mid_band
			+ smoothstep(0.5 - band_soft, 0.5 + band_soft, ndl) * (1.0 - mid_band);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
}
