// Ghibli-style cel shading for characters and props.
// Uses Godot 4's light() function to quantise lighting into discrete steps.

shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float cel_steps : hint_range(2.0, 6.0) = 3.0;
// How far light wraps around to the dark side (Ghibli fill)
uniform float wrap : hint_range(0.0, 1.0) = 0.3;
uniform vec3 shadow_color : source_color = vec3(0.12, 0.11, 0.19);  // deep indigo shadow
uniform vec3 rim_color : source_color = vec3(0.95, 0.85, 0.55);     // warm amber rim
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;


void fragment() {
	ALBEDO = (texture(albedo_tex, UV) * albedo_tint).rgb;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float wrapped = (n_dot_l + wrap) / (1.0 + wrap);
	float stepped = floor(clamp(wrapped, 0.0, 1.0) * cel_steps) / cel_steps;

	vec3 cel = mix(shadow_color, ALBEDO, stepped);

	// View-dependent warm rim halo
	float rim = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 3.0) * rim_strength;
	DIFFUSE_LIGHT += (cel + rim_color * rim) * ATTENUATION * LIGHT_COLOR;
}
