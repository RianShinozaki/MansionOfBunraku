/*
	Fire Shader for Flat Walls
	Based on Fire.gdshader with optimizations for vertical surfaces
*/
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D noise_tex;
uniform bool use_texture_noise = false;
uniform vec4 root_color : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.03, 0.001, 1.0);

uniform float fire_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 fire_speed = vec2(0.0, 1.0);
uniform float fire_aperture : hint_range(0.0, 3.0) = 0.22;
uniform float emissive_power : hint_range(0.5, 8.0) = 2.5;
uniform int color_bands : hint_range(2, 20) = 10;

// Procedural noise functions (fallback when no texture is assigned)
// Texture might be more efficient for large surfaces
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

float procedural_noise(vec2 shifted_uv) {
	return (
		value_noise(shifted_uv * 0.984864) * 20.0
	+	value_noise(shifted_uv * 2.543) * 10.0
	+	value_noise(shifted_uv * 9.543543) * 8.0
	+	value_noise(shifted_uv * 21.65436) * 5.0
	+	value_noise(shifted_uv * 42.0) * 2.0
	+	value_noise(shifted_uv * 87.135148) * 2.0
	+	value_noise(shifted_uv * 340.66534654)
	) / 48.0;
}

void fragment() {
	// Scale UV to maintain proper aspect ratio (compress horizontally)
	vec2 adjusted_uv = vec2(UV.x * 5.0, UV.y);
	vec2 shifted_uv = adjusted_uv + TIME * fire_speed;
	
	// Use texture noise if available, otherwise use procedural
	float fire_noise;
	if (use_texture_noise) {
		fire_noise = texture(noise_tex, shifted_uv).r;
	} else {
		fire_noise = procedural_noise(shifted_uv);
	}
	
	// Invert UV.y so flames are strong at bottom, fade at top
	float height = 1.0 - UV.y;
	
	// Calculate fire intensity - flames are strong at bottom, fade at top
	float noise = height * (((height + fire_aperture) * fire_noise - fire_aperture) * 75.0);
	
	// Separate alpha (smooth) from color temperature (bandable)
	float alpha_value = clamp(noise, 0.0, 1.0);
	
	// Color temperature with optional banding
	float color_temp = noise * 0.05;
	color_temp = clamp(color_temp, 0.0, 1.0);
	
	// Apply color banding if requested
	if (color_bands > 1) {
		float band_size = 1.0 / float(color_bands);
		color_temp = floor(color_temp / band_size) * band_size + band_size * 0.5;
	}
	
	// Mix colors based on temperature
	vec4 fire_color = mix(tip_color, root_color, color_temp);

	ALPHA = alpha_value * fire_alpha;
	ALBEDO = fire_color.rgb;
	EMISSION = fire_color.rgb * ALPHA * emissive_power;
}
