// Inverted-hull outline pass — applied as BaseMaterial3D.next_pass on characters.
// Renders backfaces slightly enlarged in outline colour.
// Zero extra draw calls on the mesh geometry itself.

shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.176, 0.169, 0.306, 1.0);  // deep indigo
uniform float outline_width : hint_range(0.0, 0.05) = 0.018;

void vertex() {
	// Expand along vertex normal in view space
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)
		+ vec4(view_normal * outline_width, 0.0));
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
