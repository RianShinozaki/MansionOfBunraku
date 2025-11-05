// simplified fire shader for single flame objects

shader_type spatial;
render_mode depth_draw_opaque, unshaded, shadows_disabled;

uniform sampler2D noise_tex;
uniform vec4 root_color : source_color = vec4( 1.0, 0.75, 0.3, 1.0 );
uniform vec4 tip_color : source_color = vec4( 1.0, 0.03, 0.001, 1.0 );

uniform float fire_alpha : hint_range( 0.0, 1.0 ) = 1.0;
uniform vec2 fire_speed = vec2( 0.0, 1.0 );
uniform float fire_aperture : hint_range( 0.0, 3.0 ) = 0.22;
uniform int color_bands : hint_range( 2, 20 ) = 10;

// Sphere bottom parameters
uniform float sphere_blend_height : hint_range( 0.0, 1.0 ) = 0.4;
uniform float sphere_radius : hint_range( 0.1, 2.0 ) = 0.35;

void vertex() {
	vec3 pos = VERTEX;
	
	// Cylinder height is 1.0, centered at origin: bottom at -0.5, top at 0.5
	float normalized_y = pos.y + 0.5; // 0 at bottom, 1 at top
	
	// Apply spherical deformation to the bottom portion
	if (normalized_y < sphere_blend_height) {
		// Get angle in XZ plane
		float angle_xz = atan(pos.z, pos.x);
		
		// Calculate blend factor: 0 at bottom, 1 at transition point
		float blend_factor = normalized_y / sphere_blend_height;
		
		// Map height to spherical angle (phi)
		// phi = 0 at north pole (top of sphere), PI/2 at equator
		// We want: blend_factor 0 -> phi ~PI/2 (equator), blend_factor 1 -> phi 0 (pole)
		float phi = (1.0 - blend_factor) * (3.14159265 / 2.0);
		
		// Spherical coordinates for bottom hemisphere
		// Center sphere so its top (equator) is at y = -0.5 + sphere_radius
		float sphere_center_y = -0.5 + sphere_radius;
		
		vec3 sphere_pos;
		sphere_pos.x = sphere_radius * sin(phi) * cos(angle_xz);
		sphere_pos.y = sphere_center_y - sphere_radius * cos(phi);
		sphere_pos.z = sphere_radius * sin(phi) * sin(angle_xz);
		
		// Smooth transition from sphere to cylinder
		float smooth_blend = smoothstep(0.7, 1.0, blend_factor);
		
		pos = mix(sphere_pos, pos, smooth_blend);
	}
	
	VERTEX = pos;
}

// Procedural noise (since we're not using a texture)
float random( vec2 pos )
{ 
	return fract(sin(dot(pos, vec2(12.9898,78.233))) * 43758.5453);
}

float value_noise( vec2 pos )
{
	vec2 p = floor( pos );
	vec2 f = fract( pos );

	float v00 = random( p + vec2( 0.0, 0.0 ) );
	float v10 = random( p + vec2( 1.0, 0.0 ) );
	float v01 = random( p + vec2( 0.0, 1.0 ) );
	float v11 = random( p + vec2( 1.0, 1.0 ) );

	vec2 u = f * f * ( 3.0 - 2.0 * f );

	return mix( mix( v00, v10, u.x ), mix( v01, v11, u.x ), u.y );
}

float procedural_noise_tex( vec2 shifted_uv )
{
	return (
		value_noise( shifted_uv * 0.984864 ) * 20.0
	+	value_noise( shifted_uv * 2.543 ) * 10.0
	+	value_noise( shifted_uv * 9.543543 ) * 8.0
	+	value_noise( shifted_uv * 21.65436 ) * 5.0
	+	value_noise( shifted_uv * 42.0 ) * 2.0
	+	value_noise( shifted_uv * 87.135148 ) * 2.0
	+	value_noise( shifted_uv * 340.66534654 )
	) / 48.0;
}

void fragment( )
{
	// Use 3D model-space coordinates for seamless wrapping
	vec3 model_pos = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
	
	// Sample noise from XZ plane (horizontal) for seamless cylinder wrapping
	// Scale the noise sampling to compress vertical appearance (similar to FireWall's UV.x * 5.0)
	// We scale based on the Y height to adjust aspect ratio without affecting circumferential seam
	vec2 noise_scale = vec2(1.0, 1.0 / 5.0);  // Compress Z to make features less vertically stretched. optional based on application
	vec2 shifted_uv = model_pos.xz * noise_scale + TIME * fire_speed;
	
	float fire_noise = procedural_noise_tex( shifted_uv );
	float noise = UV.y * ( ( ( UV.y + fire_aperture ) * fire_noise - fire_aperture ) * 75.0 );
	
	// Separate alpha (smooth) from color temperature (bandable)
	float alpha_value = clamp( noise, 0.0, 1.0 );
	
	// Color temperature with optional banding
	float color_temp = noise * 0.05;
	color_temp = clamp( color_temp, 0.0, 1.0 );
	
	// Apply color banding if requested
	if ( color_bands > 1 ) {
		float band_size = 1.0 / float( color_bands );
		color_temp = floor( color_temp / band_size ) * band_size + band_size * 0.5;
	}
	
	vec4 fire_color = mix( tip_color, root_color, color_temp );

	ALPHA = alpha_value * fire_alpha;
	ALBEDO = fire_color.rgb;
}
