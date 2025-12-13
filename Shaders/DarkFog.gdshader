shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_softness : hint_range(0.0, 0.6) = 0.6;
uniform float core_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.4;
uniform float noise_scale : hint_range(0.1, 10.0) = 3.0;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.3;

// Color Particle Parameters (Time Vortex inspired) - Starry Sky effect
uniform bool enable_color_particles = true;
uniform float particle_count : hint_range(1.0, 150.0) = 150.0;
uniform float particle_size : hint_range(0.0005, 0.02) = 0.003;
uniform float particle_brightness : hint_range(0.0, 5.0) = 2.0;
uniform float particle_speed : hint_range(0.0, 2.0) = 0.1;
uniform float particle_twinkle_amount : hint_range(0.0, 1.0) = 0.3;
uniform float particle_twinkle_speed : hint_range(0.0, 10.0) = 2.0;
uniform float particle_color_mix : hint_range(0.0, 1.0) = 0.5;

// Simple noise functions
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Multi-octave noise for organic variation
float multi_noise(vec2 p) {
	float result = 0.0;
	result += noise(p * 1.0) * 0.5;
	result += noise(p * 2.3) * 0.3;
	result += noise(p * 5.7) * 0.2;
	return result;
}

// Time vortex color palette
vec3 get_vortex_color(float t) {
	// Colors from TimeVortex.gdshader
	vec3 bright_cyan = vec3(0.4, 0.8, 1.0);
	vec3 purple_pink = vec3(0.7, 0.3, 0.9);
	vec3 deep_blue = vec3(0.2, 0.3, 0.7);
	vec3 white_cyan = vec3(0.95, 1.0, 1.0);
	
	// Blend between colors based on input
	vec3 color;
	if (t < 0.33) {
		color = mix(deep_blue, purple_pink, t * 3.0);
	} else if (t < 0.66) {
		color = mix(purple_pink, bright_cyan, (t - 0.33) * 3.0);
	} else {
		color = mix(bright_cyan, white_cyan, (t - 0.66) * 3.0);
	}
	
	return color;
}

// Generate color particles like a starry sky
vec3 generate_particles(vec2 uv, float time_val) {
	vec3 particle_color = vec3(0.0);
	
	// Generate multiple star-like particles
	for (float i = 0.0; i < particle_count; i += 1.0) {
		// Use different seed for each particle
		vec2 seed = vec2(i * 37.531, i * 19.277);
		
		// Generate particle position with very subtle drift
		vec2 particle_pos;
		particle_pos.x = hash(seed) + sin(time_val * particle_speed * 0.3 + i * 2.1) * 0.02;
		particle_pos.y = hash(seed + vec2(1.3, 2.7)) + cos(time_val * particle_speed * 0.2 + i * 1.7) * 0.02;
		
		// Wrap particles to keep them in bounds
		particle_pos = fract(particle_pos);
		
		// Calculate distance to particle
		float dist = length(uv - particle_pos);
		
		// Gentle twinkle effect - stars mostly stay visible
		float twinkle_phase = sin(time_val * particle_twinkle_speed + i * 6.283) * 0.5 + 0.5;
		float twinkle_phase2 = sin(time_val * particle_twinkle_speed * 0.7 + i * 4.2) * 0.5 + 0.5;
		float twinkle = mix(1.0 - particle_twinkle_amount, 1.0, twinkle_phase * twinkle_phase2);
		
		// Create star-like point with soft glow
		float core_size = particle_size * 0.3;
		float glow_size = particle_size;
		
		// Sharp bright core
		float core = 1.0 - smoothstep(0.0, core_size, dist);
		core = pow(core, 8.0);
		
		// Softer glow around it
		float glow = 1.0 - smoothstep(0.0, glow_size, dist);
		glow = pow(glow, 3.0);
		
		// Combine core and glow
		float particle_intensity = core + glow * 0.5;
		particle_intensity *= twinkle;
		
		// Select color based on particle index with slow color drift
		float color_select = hash(seed + vec2(time_val * 0.03, 0.0));
		color_select = mix(color_select, particle_color_mix, 0.5);
		vec3 this_color = get_vortex_color(color_select);
		
		// Create star with brightness
		vec3 star = this_color * particle_intensity * particle_brightness;
		
		particle_color += star;
	}
	
	return particle_color;
}

void fragment() {
	// Get UV coordinates (0 to 1)
	vec2 uv = UV;
	
	// Calculate distance from edges (0 at edge, 0.5 at center)
	float dist_from_left = uv.x;
	float dist_from_right = 1.0 - uv.x;
	float dist_from_top = uv.y;
	float dist_from_bottom = 1.0 - uv.y;
	
	// Find minimum distance to any edge
	float min_dist_horizontal = min(dist_from_left, dist_from_right);
	float min_dist_vertical = min(dist_from_top, dist_from_bottom);
	float min_dist = min(min_dist_horizontal, min_dist_vertical);
	
	// Create smooth edge gradient
	float edge_alpha = smoothstep(0.0, edge_softness, min_dist);
	
	// Add animated noise for fog effect
	vec2 noise_uv = uv * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed * 0.7);
	float fog_noise = noise(noise_uv);
	fog_noise = fog_noise * 2.0 - 1.0; // Range -1 to 1
	
	// Apply noise to alpha only at edges, keep center solid
	float base_alpha = edge_alpha * core_opacity;
	
	// Only add noise near edges (where edge_alpha < 1.0)
	// Use a stronger falloff to ensure center stays completely opaque
	float noise_blend = pow(1.0 - edge_alpha, 2.0); // Higher at edges, 0 at center
	float noise_contribution = fog_noise * noise_strength * noise_blend;
	
	float final_alpha = base_alpha + noise_contribution;
	final_alpha = clamp(final_alpha, 0.0, core_opacity);
	
	// Add color particles if enabled
	vec3 final_albedo = fog_color.rgb;
	if (enable_color_particles) {
		vec3 particles = generate_particles(uv, TIME);
		// Blend particles additively so they glow
		final_albedo += particles;
	}
	
	// Set output - make center fully opaque
	ALBEDO = final_albedo;
	ALPHA = final_alpha * fog_color.a;
}
