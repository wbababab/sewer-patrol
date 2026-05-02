// Ghibli-style cel shading for characters and props.
// Quantises lighting into discrete steps for a hand-painted look.
// Preserves the warm Ghibli palette by using a warm light wrap term.

shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float cel_steps : hint_range(2.0, 6.0) = 3.0;
// How far light "wraps" around to the dark side (Ghibli fill light)
uniform float wrap : hint_range(0.0, 1.0) = 0.3;
uniform vec3 shadow_color : source_color = vec3(0.12, 0.11, 0.19);  // deep indigo shadow
uniform vec3 rim_color : source_color = vec3(0.95, 0.85, 0.55);     // warm amber rim
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;


void fragment() {
	vec4 tex_col = texture(albedo_tex, UV) * albedo_tint;

	// Diffuse wrap
	float n_dot_l = dot(NORMAL, LIGHT) * 0.5 + 0.5;  // remap to [0,1] with wrap
	float wrapped = (n_dot_l + wrap) / (1.0 + wrap);

	// Cel quantise
	float stepped = floor(wrapped * cel_steps) / cel_steps;

	// Blend between shadow colour and albedo based on stepped lighting
	vec3 diffuse = mix(shadow_color, tex_col.rgb, stepped);

	// Rim light (view-dependent warm halo)
	float rim = 1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0);
	rim = pow(rim, 3.0) * rim_strength;
	diffuse += rim_color * rim;

	ALBEDO = diffuse;
	ALPHA = tex_col.a;
}
