shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

// Fill level from 0.0 (empty) to 1.0 (full)
uniform float fill_level : hint_range(0.0, 1.0) = 0.0;
// Sake color - more saturated yellow for better visibility
uniform vec4 sake_color : source_color = vec4(0.98, 0.95, 0.75, 0.85);
// Cup interior mask - defines where liquid can appear
uniform sampler2D cup_interior_mask : source_color;
// Wave animation parameters
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	// Get UV coordinates
	vec2 uv = UV;
	
	// Avoid division by zero
	if (fill_level < 0.01) {
		ALPHA = 0.0;
	} else {
		// Scale UVs from center outward based on fill_level
		// When fill_level is small, we zoom in on center; when full, we see the whole texture
		vec2 center = vec2(0.5, 0.5);
		vec2 uv_scaled = (uv - center) / fill_level + center;
		
		// Add wave animation to UVs for liquid movement
		float wave_offset_x = sin(TIME * wave_speed * 3.0 + uv.y * 10.0) * wave_amplitude;
		float wave_offset_y = cos(TIME * wave_speed * 2.5 + uv.x * 8.0) * wave_amplitude;
		uv_scaled.x += wave_offset_x * fill_level;
		uv_scaled.y += wave_offset_y * fill_level;
		
		// Check if scaled UV is outside 0-1 range (outside original texture bounds)
		if (uv_scaled.x < 0.0 || uv_scaled.x > 1.0 || uv_scaled.y < 0.0 || uv_scaled.y > 1.0) {
			ALPHA = 0.0;
		} else {
			// Sample mask at scaled coordinates
			vec4 mask = texture(cup_interior_mask, uv_scaled);
			float mask_alpha = mask.r > 0.5 ? 1.0 : 0.0;
			
			if (mask_alpha < 0.5) {
				ALPHA = 0.0;
			} else {
				// Base sake color
				vec3 base_color = sake_color.rgb;
				ALBEDO = base_color;
				
				// Add gradient from center for depth
				float dist_from_center = length(uv - center);
				ALBEDO = ALBEDO * (0.85 + 0.15 * (1.0 - dist_from_center * 2.0));
				
				// Liquid shimmer effect - subtle highlights that move
				float shimmer = sin(TIME * wave_speed * 4.0 + uv.x * 15.0 + uv.y * 12.0) * 0.5 + 0.5;
				shimmer = pow(shimmer, 3.0) * 0.15; // Make highlights sharper and subtler
				ALBEDO += vec3(shimmer);
				
				// More translucent alpha with slight variation for liquid feel
				float alpha_variation = sin(TIME * wave_speed * 2.0 + dist_from_center * 8.0) * 0.05;
				ALPHA = sake_color.a - 0.1 + alpha_variation; // Slightly more translucent
				
				// Subtle emission for glow
				EMISSION = ALBEDO * 0.15;
			}
		}
	}
}
