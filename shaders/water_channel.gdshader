// Animated water for cisterns and floor channels.
// Two overlapping normal maps scroll in different directions.
// Ghibli palette: dusty teal base, pale gold specular.

shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D normal_map_a : hint_normal;
uniform sampler2D normal_map_b : hint_normal;
uniform vec2 scroll_a = vec2(0.04, 0.02);
uniform vec2 scroll_b = vec2(-0.02, 0.05);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
// Ghibli water colours
uniform vec4 shallow_color : source_color = vec4(0.42, 0.62, 0.67, 0.75);   // dusty teal
uniform vec4 deep_color    : source_color = vec4(0.17, 0.17, 0.31, 0.90);   // deep indigo
uniform float depth_blend : hint_range(0.0, 1.0) = 0.5;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
// Subtle foam at edges
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.1;


void fragment() {
	vec2 uv_a = UV + scroll_a * TIME;
	vec2 uv_b = UV + scroll_b * TIME;

	vec3 norm_a = texture(normal_map_a, uv_a).xyz * 2.0 - 1.0;
	vec3 norm_b = texture(normal_map_b, uv_b).xyz * 2.0 - 1.0;
	vec3 blended_norm = normalize(norm_a + norm_b) * normal_strength;

	// Depth-based colour blend (simple: use UV distance from centre as proxy)
	float dist = length(UV - vec2(0.5));
	vec4 water_col = mix(shallow_color, deep_color, clamp(dist * depth_blend * 2.0, 0.0, 1.0));

	// Soft foam near edges
	float foam = smoothstep(0.45, 0.5, dist);
	water_col.rgb = mix(water_col.rgb, vec3(0.94, 0.94, 0.88), foam * 0.35);

	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	NORMAL_MAP = blended_norm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = specular_strength;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
