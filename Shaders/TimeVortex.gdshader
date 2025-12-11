/*
	Time Vortex Shader
	Creates a swirling spiral effect that distorts the scene viewport
	Used for time travel transitions
*/
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float vortex_opacity : hint_range(0.0, 1.0) = 1.0;  // NEW: Controls vortex color visibility independently
uniform bool clockwise = true;
uniform float distortion_strength : hint_range(0.0, 20.0) = 8.0;
uniform float rotation_speed : hint_range(0.0, 5.0) = 0.5;
uniform vec4 center_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 inner_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.7, 0.3, 0.9, 1.0);
uniform vec4 vortex_color : source_color = vec4(0.2, 0.3, 0.7, 1.0);
uniform vec4 edge_color : source_color = vec4 (0.05, 0.05, 0.3, 1.0);
uniform float center_size : hint_range(0.0, 1.0) = 0.3;
uniform float center_gradient_power : hint_range(1.0, 5.0) = 3.0;
uniform float color_shift_speed : hint_range(0.0, 5.0) = 0.6;
uniform float breath_strength : hint_range(0.0, 0.3) = 0.08;
uniform float breath_speed : hint_range(0.0, 5.0) = 0.9;
uniform float radial_speed_power : hint_range(0.5, 3.0) = 2.0;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.005;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.15;
uniform sampler2D vortex_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture_overlay = false;
uniform float texture_scroll_speed_x : hint_range(-1.0, 1.0) = 0.1;
uniform float texture_scroll_speed_y : hint_range(-1.0, 1.0) = 0.05;
uniform float texture_rotation_speed : hint_range(-2.0, 2.0) = 0.15;
uniform float texture_scale : hint_range(0.5, 5.0) = 2.0;
uniform float texture_blend : hint_range(0.0, 1.0) = 0.4;

// Retro/Pixel Art Style Controls
uniform bool enable_pixelation = false;
uniform float pixelation_amount : hint_range(1.0, 500.0) = 400.0;
uniform bool enable_color_banding = true;
uniform int color_bands : hint_range(2, 32) = 4;

// Organic Swirl Controls
uniform float spiral_noise_amount : hint_range(0.0, 1.5) = 1.5;
uniform float spiral_noise_scale : hint_range(0.5, 10.0) = 10.0;

// Color Band Noise/Grain Controls
uniform bool enable_band_noise = true;
uniform float band_noise_strength : hint_range(0.0, 0.2) = 0.2;
uniform float band_noise_scale : hint_range(10.0, 500.0) = 300.0;

// Organic Edge Disruption Controls
uniform bool enable_flame_edges = true;
uniform float flame_displacement : hint_range(0.0, 0.3) = 0.1;
uniform float flame_frequency : hint_range(2.0, 20.0) = 8.0;
uniform float flame_turbulence : hint_range(0.0, 2.0) = 1.0;
uniform float flame_flicker_speed : hint_range(0.0, 3.0) = 1.5;

// Spiral Arms/Galaxy Effect Controls
uniform bool enable_spiral_arms = true;
uniform int spiral_arm_count : hint_range(2, 8) = 3;
uniform float spiral_arm_tightness : hint_range(2.0, 10.0) = 5.0;
uniform float spiral_arm_strength : hint_range(0.0, 1.0) = 0.6;
uniform float spiral_arm_sharpness : hint_range(1.0, 10.0) = 3.0;

// Sparkle/Particle Effect Controls
uniform bool enable_sparkles = true;
uniform float sparkle_density : hint_range(0.0, 100.0) = 30.0;
uniform float sparkle_brightness : hint_range(0.0, 2.0) = 1.2;
uniform float sparkle_size : hint_range(0.001, 0.01) = 0.003;
uniform float sparkle_twinkle_speed : hint_range(0.0, 5.0) = 2.0;

// Enhanced Glow/Bloom Controls
uniform bool enable_enhanced_glow = true;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float glow_radius : hint_range(0.1, 0.8) = 0.4;
uniform float glow_falloff : hint_range(1.0, 5.0) = 2.5;

// Vortex Trails/Motion Blur Controls
uniform bool enable_trails = true;
uniform int trail_length : hint_range(2, 8) = 4;
uniform float trail_strength : hint_range(0.0, 0.5) = 0.25;
uniform float trail_spacing : hint_range(0.01, 0.1) = 0.03;

// Lightning/Electric Arcs Controls
uniform bool enable_lightning = false;
uniform float lightning_frequency : hint_range(0.0, 10.0) = 3.0;
uniform float lightning_brightness : hint_range(0.0, 5.0) = 2.5;
uniform float lightning_thickness : hint_range(0.001, 0.01) = 0.002;
uniform vec4 lightning_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);

// Simple noise function for grain effect
float noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Multi-octave noise functions from fire shader for organic turbulence
float random(vec2 pos) { 
	return fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 pos) {
	vec2 p = floor(pos);
	vec2 f = fract(pos);

	float v00 = random(p + vec2(0.0, 0.0));
	float v10 = random(p + vec2(1.0, 0.0));
	float v01 = random(p + vec2(0.0, 1.0));
	float v11 = random(p + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(v00, v10, u.x), mix(v01, v11, u.x), u.y);
}

// Layered multi-octave noise for organic turbulence
float turbulent_noise(vec2 uv) {
	return (
		value_noise(uv * 0.984864) * 20.0
	+	value_noise(uv * 2.543) * 10.0
	+	value_noise(uv * 9.543543) * 8.0
	+	value_noise(uv * 21.65436) * 5.0
	+	value_noise(uv * 42.0) * 2.0
	+	value_noise(uv * 87.135148) * 2.0
	+	value_noise(uv * 340.66534654)
	) / 48.0;
}

// Calculate spiral arm intensity at a given angle and distance
float calculate_spiral_arms(float angle, float distance, float time_offset) {
	// Create rotating spiral pattern
	float spiral_angle = angle * float(spiral_arm_count) - distance * spiral_arm_tightness + time_offset;
	float arm_pattern = sin(spiral_angle);
	
	// Sharpen the arms to create distinct bright regions
	arm_pattern = pow(abs(arm_pattern), 1.0 / spiral_arm_sharpness);
	
	// Fade arms based on distance (stronger in mid-range)
	float radial_fade = smoothstep(0.0, 0.2, distance) * smoothstep(1.0, 0.5, distance);
	
	return arm_pattern * radial_fade;
}

// Generate sparkle/particle points
float generate_sparkles(vec2 uv, float angle, float distance, float time_val) {
	// Create rotating sparkle field
	float rotated_angle = angle + time_val * 0.5;
	vec2 sparkle_uv = vec2(rotated_angle * sparkle_density, distance * sparkle_density);
	sparkle_uv += vec2(time_val * 0.3, time_val * 0.2);
	
	// Layer multiple noise scales for variety
	float sparkle_noise = value_noise(sparkle_uv * 1.0);
	sparkle_noise += value_noise(sparkle_uv * 2.5) * 0.5;
	sparkle_noise += value_noise(sparkle_uv * 5.0) * 0.25;
	sparkle_noise /= 1.75;
	
	// Twinkle animation
	float twinkle = sin(time_val * sparkle_twinkle_speed + sparkle_noise * 10.0) * 0.5 + 0.5;
	
	// Threshold to create discrete points
	float threshold = 0.85;
	float sparkle = smoothstep(threshold, threshold + sparkle_size, sparkle_noise * twinkle);
	
	// Fade sparkles based on distance (more in middle ranges)
	float sparkle_fade = smoothstep(0.1, 0.3, distance) * smoothstep(1.0, 0.6, distance);
	
	return sparkle * sparkle_fade;
}

// Calculate enhanced glow with multiple falloff layers
float calculate_enhanced_glow(float distance, float center_dist) {
	// Multiple glow layers at different scales
	float glow1 = smoothstep(glow_radius, 0.0, distance);
	float glow2 = smoothstep(glow_radius * 1.5, 0.0, distance);
	float glow3 = smoothstep(glow_radius * 2.0, 0.0, distance);
	
	// Apply falloff curve
	glow1 = pow(glow1, glow_falloff);
	glow2 = pow(glow2, glow_falloff * 1.3);
	glow3 = pow(glow3, glow_falloff * 1.8);
	
	// Combine layers with decreasing intensity
	float combined_glow = glow1 + glow2 * 0.5 + glow3 * 0.25;
	
	return combined_glow;
}

// Generate lightning arcs
float generate_lightning(vec2 uv, float angle, float distance, float time_val) {
	// Create multiple potential lightning paths
	float lightning_result = 0.0;
	
	// Use noise to determine if lightning should appear at this location
	vec2 lightning_coord = vec2(angle * lightning_frequency, distance * 5.0);
	float lightning_base_noise = value_noise(lightning_coord + time_val * 0.8);
	
	// Only create lightning in specific regions (sporadic appearance)
	if (lightning_base_noise > 0.75) {
		// Create jagged path using layered noise
		float path_noise = value_noise(vec2(angle * lightning_frequency * 3.0, time_val * 2.0));
		path_noise += value_noise(vec2(angle * lightning_frequency * 7.0, time_val * 3.0)) * 0.5;
		
		// Create thin lightning bolt
		float bolt_thickness = lightning_thickness * (1.0 + path_noise * 0.5);
		float bolt_distance = abs(path_noise - 0.5);
		lightning_result = smoothstep(bolt_thickness, 0.0, bolt_distance);
		
		// Flicker effect
		float flicker = sin(time_val * 20.0 + lightning_base_noise * 100.0) * 0.3 + 0.7;
		lightning_result *= flicker;
		
		// Fade based on distance
		lightning_result *= smoothstep(0.1, 0.2, distance) * smoothstep(0.9, 0.7, distance);
	}
	
	return lightning_result;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixelated_uv = uv;
	
	// Apply pixelation effect by snapping UV to a grid
	// Keep original uv for vortex calculations, use pixelated_uv for screen sampling
	if (enable_pixelation) {
		vec2 pixel_size = vec2(1.0) / pixelation_amount;
		pixelated_uv = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;
	}
	
	vec2 center = vec2(0.5, 0.5);
	
	// Convert to polar coordinates (use original UV for smooth vortex)
	vec2 to_center = uv - center;
	float distance = length(to_center);
	float angle = atan(to_center.y, to_center.x);
	
	// === ORGANIC EDGE DISRUPTION ===
	// Use pure noise to make edges irregular and fire-like
	float edge_displacement = 0.0;
	if (enable_flame_edges && progress > 0.0) {
		// Sample multiple noise layers at different scales based on angle
		vec2 noise_coord1 = vec2(angle * flame_frequency, TIME * flame_flicker_speed);
		vec2 noise_coord2 = vec2(angle * flame_frequency * 2.5, TIME * flame_flicker_speed * 1.3);
		vec2 noise_coord3 = vec2(angle * flame_frequency * 5.0, TIME * flame_flicker_speed * 0.7);
		
		// Layer noise at different frequencies for detail
		float noise1 = turbulent_noise(noise_coord1) - 0.5;
		float noise2 = turbulent_noise(noise_coord2) - 0.5;
		float noise3 = turbulent_noise(noise_coord3) - 0.5;
		
		// Combine noise layers with different weights
		float combined_noise = noise1 * 0.6 + noise2 * 0.3 + noise3 * 0.1;
		
		// Scale by displacement amount and turbulence
		edge_displacement = combined_noise * flame_displacement * flame_turbulence * progress;
		
		// Apply radial mask - stronger effect in middle range
		float radial_mask = smoothstep(0.2, 0.4, distance) * smoothstep(1.0, 0.7, distance);
		edge_displacement *= radial_mask;
	}
	
	// Apply edge displacement to create organic, wavy edges
	float effective_distance = distance - edge_displacement;
	
	// Apply breathing/pulsation effect (radial expansion/contraction)
	float breath_pulse = sin(TIME * breath_speed) * breath_strength * progress;
	float breathing_distance = effective_distance + breath_pulse * (1.0 - effective_distance);
	
	// Use breathing distance for color calculations but original for distortion
	// This creates the pulsing visual without affecting the spiral distortion too much
	
	// Apply spiral distortion based on distance and progress
	// More distortion near the center, controlled by progress
	float distortion = progress * distortion_strength * (1.0 - distance);
	
	// Add radial speed gradient - inner areas rotate faster than outer
	// Use power function to control the falloff curve
	float radial_speed_multiplier = pow(1.0 - distance, radial_speed_power);
	
	// Add time-based rotation for animated swirl with radial gradient
	float time_rotation = TIME * rotation_speed * progress * (0.3 + radial_speed_multiplier * 0.7);
	
	// Add organic turbulent noise to make spiral less circular (fire-like)
	// Use multi-octave noise for that flickering, turbulent quality
	vec2 noise_uv = vec2(angle * spiral_noise_scale, distance * spiral_noise_scale) + TIME * vec2(0.3, 0.2);
	float turbulence = turbulent_noise(noise_uv);
	float spiral_noise = (turbulence - 0.5) * spiral_noise_amount * progress;
	
	// Combine rotation (direction-dependent)
	float total_rotation = distortion + time_rotation + spiral_noise;
	if (!clockwise) {
		total_rotation = -total_rotation;
	}
	
	angle += total_rotation;
	
	// Reconstruct distorted UV coordinates
	vec2 distorted_uv = center + vec2(cos(angle), sin(angle)) * distance;
	
	// Apply pixelation to the distorted coordinates if enabled
	if (enable_pixelation) {
		vec2 pixel_size = vec2(1.0) / pixelation_amount;
		distorted_uv = floor(distorted_uv / pixel_size) * pixel_size + pixel_size * 0.5;
	}
	
	// === MOTION BLUR / TRAILS EFFECT ===
	vec4 scene_color;
	if (enable_trails && progress > 0.0) {
		// Sample multiple points along the spiral path for motion blur
		vec4 trail_accumulation = vec4(0.0);
		float total_weight = 0.0;
		
		for (int i = 0; i < trail_length; i++) {
			// Calculate offset angle for trail sampling
			float trail_offset = float(i) * trail_spacing;
			float trail_angle = angle - trail_offset * (clockwise ? 1.0 : -1.0);
			
			// Reconstruct UV for this trail sample
			vec2 trail_uv = center + vec2(cos(trail_angle), sin(trail_angle)) * distance;
			
			// Weight decreases for older trail positions
			float weight = 1.0 - (float(i) / float(trail_length));
			weight = pow(weight, 2.0); // Exponential falloff
			
			// Apply chromatic aberration to trail samples too
			float aberration_strength = chromatic_aberration * progress * (1.0 - distance * 0.5);
			vec2 aberration_offset = (trail_uv - center) * aberration_strength;
			
			// Sample with chromatic aberration
			float r = texture(screen_texture, trail_uv + aberration_offset).r;
			float g = texture(screen_texture, trail_uv).g;
			float b = texture(screen_texture, trail_uv - aberration_offset).b;
			
			trail_accumulation += vec4(r, g, b, 1.0) * weight;
			total_weight += weight;
		}
		
		// Normalize and blend with trail strength
		vec4 trail_color = trail_accumulation / total_weight;
		
		// Sample current position for blending
		float aberration_strength = chromatic_aberration * progress * (1.0 - distance * 0.5);
		vec2 aberration_offset = to_center * aberration_strength;
		float r = texture(screen_texture, distorted_uv + aberration_offset).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - aberration_offset).b;
		vec4 current_color = vec4(r, g, b, 1.0);
		
		// Blend trails based on rotation speed (more blur when spinning faster)
		float trail_intensity = trail_strength * progress * (1.0 - distance * 0.3);
		scene_color = mix(current_color, trail_color, trail_intensity);
	} else {
		// Standard chromatic aberration without trails
		float aberration_strength = chromatic_aberration * progress * (1.0 - distance * 0.5);
		vec2 aberration_offset = to_center * aberration_strength;
		
		float r = texture(screen_texture, distorted_uv + aberration_offset).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - aberration_offset).b;
		
		scene_color = vec4(r, g, b, 1.0);
	}
	
	// Create multi-layered vortex colors with time-based shifting
	// Use breathing_distance for more dynamic color zones
	float vortex_gradient = smoothstep(center_size, 0.0, breathing_distance);
	// Apply power function for much more gradual, softer falloff
	vortex_gradient = pow(vortex_gradient, center_gradient_power);
	
	// Time-based color pulsing
	float color_pulse = sin(TIME * color_shift_speed) * 0.5 + 0.5;
	
	// Create five color zones with pulsing (center -> inner -> mid -> vortex -> edge)
	vec4 outer_ring = mix(edge_color, vortex_color, color_pulse);
	vec4 outer_mid = mix(vortex_color, mid_color, color_pulse);
	vec4 inner_mid = mix(mid_color, inner_color, color_pulse);
	vec4 inner_core = mix(inner_color, center_color, color_pulse * 0.5);
	
	// Blend between zones based on breathing distance for pulsing effect
	vec4 vortex;
	if (breathing_distance > 0.7) {
		// Outermost edge zone (0.7 - 1.0)
		float outer_blend = smoothstep(0.7, 1.0, breathing_distance);
		vortex = mix(outer_mid, outer_ring, outer_blend);
	} else if (breathing_distance > 0.5) {
		// Outer-mid zone (0.5 - 0.7)
		float mid_blend = smoothstep(0.5, 0.7, breathing_distance);
		vortex = mix(inner_mid, outer_mid, mid_blend);
	} else if (breathing_distance > 0.25) {
		// Inner-mid zone (0.25 - 0.5)
		float inner_blend = smoothstep(0.25, 0.5, breathing_distance);
		vortex = mix(inner_core, inner_mid, inner_blend);
	} else {
		// Center core zone (0.0 - 0.25)
		float center_blend = smoothstep(0.0, 0.25, breathing_distance);
		vortex = mix(center_color, inner_core, center_blend);
	}
	
	// Apply the center gradient overlay for extra brightness in the middle
	vortex = mix(vortex, center_color, vortex_gradient * 0.7);
	
	// Add texture overlay for organic detail (if enabled)
	if (use_texture_overlay) {
		// Transform UVs for texture sampling
		vec2 tex_uv = (uv - center) * texture_scale;
		
		// Apply rotation based on TIME
		float tex_angle = TIME * texture_rotation_speed;
		float tex_sin = sin(tex_angle);
		float tex_cos = cos(tex_angle);
		mat2 tex_rot = mat2(vec2(tex_cos, -tex_sin), vec2(tex_sin, tex_cos));
		tex_uv = tex_rot * tex_uv;
		
		// Apply scrolling
		vec2 tex_scroll = vec2(texture_scroll_speed_x, texture_scroll_speed_y) * TIME;
		tex_uv += tex_scroll;
		
		// Center the UVs for texture sampling
		tex_uv += 0.5;
		
		// Sample texture
		vec4 tex_color = texture(vortex_texture, tex_uv);
		
		// Blend texture with vortex colors, stronger near center
		float tex_strength = texture_blend * progress * (1.0 - distance * 0.5);
		vortex.rgb = mix(vortex.rgb, vortex.rgb * tex_color.rgb, tex_strength);
	}
	
	// Blend scene with vortex based on progress
	// Use gentler power curve to show more vortex colors throughout transition
	float dissolve = pow(progress, 0.7);
	
	// Apply edge softness - reduce vortex effect near screen edges for smoother integration
	// Use radial distance for circular mask instead of rectangular
	float edge_mask = 1.0;
	if (edge_softness > 0.0) {
		// Create circular vignette-style mask based on distance from center
		// This prevents harsh rectangular artifacts
		float edge_falloff = 1.0 - distance;
		edge_mask = smoothstep(0.0, edge_softness, edge_falloff);
	}
	
	// Apply edge mask to dissolve for softer screen edges
	// Also apply vortex_opacity to allow independent control of vortex color visibility
	float masked_dissolve = dissolve * edge_mask * vortex_opacity;
	vec4 final_color = mix(scene_color, vortex, masked_dissolve);
	
	// === LAYER VISUAL EFFECTS ===
	// Only apply when vortex is visible
	if (progress > 0.0) {
		
		// 1. SPIRAL ARMS - Modulate vortex colors to create galaxy-like arms
		if (enable_spiral_arms) {
			float arm_intensity = calculate_spiral_arms(angle, distance, TIME * rotation_speed);
			// Brighten along spiral arms
			vec3 arm_glow = vortex.rgb * arm_intensity * spiral_arm_strength;
			final_color.rgb = mix(final_color.rgb, final_color.rgb + arm_glow, masked_dissolve);
		}
		
		// 2. ENHANCED GLOW - Multi-layer bloom effect in center
		if (enable_enhanced_glow) {
			float enhanced_glow = calculate_enhanced_glow(distance, vortex_gradient);
			vec3 glow_color = center_color.rgb * enhanced_glow * glow_intensity * progress;
			final_color.rgb += glow_color * masked_dissolve;
		}
		
		// 3. SPARKLES - Bright twinkling points throughout vortex
		if (enable_sparkles) {
			float sparkle_intensity = generate_sparkles(uv, angle, distance, TIME);
			vec3 sparkle_color = center_color.rgb * sparkle_intensity * sparkle_brightness;
			final_color.rgb += sparkle_color * masked_dissolve;
		}
		
		// 4. LIGHTNING ARCS - Electric bolts connecting spiral regions
		if (enable_lightning) {
			float lightning_intensity = generate_lightning(uv, angle, distance, TIME);
			vec3 bolt_color = lightning_color.rgb * lightning_intensity * lightning_brightness;
			final_color.rgb += bolt_color * masked_dissolve;
		}
	}
	
	// Apply color banding for retro look BEFORE adding center glow
	// This prevents harsh banding artifacts in the bright center
	if (enable_color_banding && color_bands > 1) {
		// Add grainy noise/static to the banded colors
		if (enable_band_noise) {
			vec2 noise_uv = uv * band_noise_scale;
			// Use layered smooth noise instead of simple hash noise to avoid zigzag patterns
			float grain = value_noise(noise_uv) * 0.5;
			grain += value_noise(noise_uv * 2.3) * 0.3;
			grain += value_noise(noise_uv * 5.7) * 0.2;
			grain = (grain - 0.5) * band_noise_strength;
			final_color.rgb += vec3(grain) * masked_dissolve; // Only apply grain to vortex areas
		}
		
		float band_size = 1.0 / float(color_bands);
		final_color.r = floor(final_color.r / band_size) * band_size + band_size * 0.5;
		final_color.g = floor(final_color.g / band_size) * band_size + band_size * 0.5;
		final_color.b = floor(final_color.b / band_size) * band_size + band_size * 0.5;
	}
	
	// Add extra glow in the center as effect intensifies
	// Applied after banding to keep the bright center smooth
	float center_glow = vortex_gradient * progress;
	final_color.rgb += center_color.rgb * center_glow * 0.5;
	
	COLOR = final_color;
}
