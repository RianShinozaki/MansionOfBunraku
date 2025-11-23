shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

// Fill level from 0.0 (empty) to 1.0 (full) - set to target level
uniform float fill_level : hint_range(0.0, 1.0) = 0.4;
// Target outline color - blue
uniform vec4 line_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
// Cup interior mask - defines where liquid can appear
uniform sampler2D cup_interior_mask : source_color, filter_nearest;
// Dotted line parameters
uniform float dash_length : hint_range(0.01, 0.5) = 0.08;
uniform float gap_length : hint_range(0.01, 0.5) = 0.05;
// Edge detection thickness
uniform float edge_thickness : hint_range(0.001, 0.1) = 0.02;
uniform float line_width : hint_range(0.001, 0.1) = 0.025;

void fragment() {
	// Get UV coordinates
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	
	// Avoid division by zero
	if (fill_level < 0.01) {
		discard;
	}
	
	// Apply center-out scaling at target fill level
	vec2 uv_at_target = (uv - center) / fill_level + center;
	
	// Apply center-out scaling at slightly less fill (inner boundary)
	float inner_fill = fill_level - line_width;
	vec2 uv_at_inner = (uv - center) / inner_fill + center;
	
	// Check bounds
	if (uv_at_target.x < 0.0 || uv_at_target.x > 1.0 || 
	    uv_at_target.y < 0.0 || uv_at_target.y > 1.0) {
		discard;
	}
	
	// Sample masks
	float mask_at_target = texture(cup_interior_mask, uv_at_target).r;
	float mask_at_inner = texture(cup_interior_mask, uv_at_inner).r;
	
	// Draw outline: visible at target level BUT NOT visible at inner level
	// This creates a ring at the boundary
	bool at_boundary = (mask_at_target > 0.5) && (mask_at_inner < 0.5);
	
	if (!at_boundary) {
		discard;
	}
	
	// Create dotted pattern using angle around center for circular effect
	float angle = atan(uv.y - center.y, uv.x - center.x);
	// Normalize angle to 0-2π range
	float normalized_angle = (angle + 3.14159) / (2.0 * 3.14159);
	float pattern = mod(normalized_angle * 40.0, dash_length + gap_length);
	
	// Discard fragments in the gap between dashes
	if (pattern > dash_length) {
		discard;
	}
	
	// Draw the line - bright with strong emission
	ALBEDO = line_color.rgb;
	ALPHA = 1.0;
	EMISSION = line_color.rgb * 0.8;
}
