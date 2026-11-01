shader_type spatial;
// Inverted hull: back faces pushed out along the screen-space normal by a
// fixed pixel width, so the line stays the same weight when the camera zooms.
render_mode unshaded, cull_front, specular_disabled, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.478, 0.322, 0.2, 1.0);
// Pixels at the 1600 px design height; scaled to the real viewport.
uniform float thickness_px = 3.2;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(dir);
	if (len > 0.00001) {
		dir /= len;
	}
	float px = thickness_px * VIEWPORT_SIZE.y / 1600.0;
	clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
