shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

// =====================================================
// FIRE SHADER - multi-flame effect
// =====================================================

// ---------- Fire Appearance ----------
uniform vec3 fire_color_hot : source_color = vec3(1.0, 0.95, 0.8);    // bright yellow-white
uniform vec3 fire_color_mid : source_color = vec3(1.0, 0.35, 0.1);    // orange
uniform vec3 fire_color_base : source_color = vec3(0.8, 0.05, 0.0);   // deep red
uniform vec3 ember_color : source_color = vec3(0.3, 0.02, 0.0);       // dark ember

// ---------- Fire Behavior ----------
uniform float fire_intensity : hint_range(0.0, 1.0) = 1.0;            // overall strength
uniform float fire_scale : hint_range(0.1, 10.0) = 1.0;               // pattern size
uniform float fire_speed : hint_range(0.1, 3.0) = 1.0;                // animation speed
uniform float flame_height : hint_range(0.3, 3.0) = 1.0;              // vertical stretch
uniform float turbulence : hint_range(0.0, 3.0) = 1.0;                // chaos amount
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;            // pulse rate
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.3;            // pulse strength

// ---------- Shape & Opacity ----------
uniform float edge_softness : hint_range(0.0, 1.0) = 0.4;             // soft flame edges
uniform float core_density : hint_range(0.0, 2.0) = 0.8;              // center opacity
uniform float tip_fadeout : hint_range(0.0, 2.0) = 1.2;               // fade at top

// ---------- Multi-Flame Organic Look ----------
uniform int flame_tongues : hint_range(2, 8) = 4;                     // number of flame columns
uniform float flame_separation : hint_range(0.0, 1.0) = 0.4;          // gaps between flames
uniform float flame_variation : hint_range(0.0, 1.0) = 0.6;           // how different each tongue is
uniform float flame_irregularity : hint_range(0.0, 1.0) = 0.5;        // organic shape breaking

// ---------- Visual Enhancement ----------
uniform float emissive_power : hint_range(0.5, 8.0) = 2.5;            // light emission
uniform float color_variation : hint_range(0.0, 1.0) = 0.3;           // color noise
uniform float horizontal_drift : hint_range(0.0, 1.0) = 0.3;          // side-to-side motion

// ---------- Billboard Option ----------
uniform bool face_camera = false;                                      // rotate toward camera

// =====================================================
// Noise Functions, random-based
// =====================================================

// Hash function for pseudo-random values
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

// 3D noise
float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    
    // Sample corners of cube
    float a = hash(i);
    float b = hash(i + vec3(1.0, 0.0, 0.0));
    float c = hash(i + vec3(0.0, 1.0, 0.0));
    float d = hash(i + vec3(1.0, 1.0, 0.0));
    float e = hash(i + vec3(0.0, 0.0, 1.0));
    float f2 = hash(i + vec3(1.0, 0.0, 1.0));
    float g = hash(i + vec3(0.0, 1.0, 1.0));
    float h = hash(i + vec3(1.0, 1.0, 1.0));
    
    // Trilinear interpolation
    return mix(
        mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
        mix(mix(e, f2, f.x), mix(g, h, f.x), f.y),
        f.z
    );
}

// FBM - Fractional Brownian Motion (3 octaves for web performance)
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise3d(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// =====================================================
// Vertex Shader
// =====================================================
void vertex() {
    if (face_camera) {
        // Billboard effect - rotate to face camera
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
            vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
            vec4(0.0, 1.0, 0.0, 0.0),
            vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
            MODEL_MATRIX[3]
        );
        MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
            vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
            vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
            vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
            vec4(0.0, 0.0, 0.0, 1.0)
        );
    }
}

// =====================================================
// Fragment Shader - Fire Generation
// =====================================================
void fragment() {
    float t = TIME * fire_speed;
    
    // Get UV coordinates (using UV or local position)
    vec2 uv = UV;
    uv.y = 1.0 - uv.y; // FLIP UV vertically so flames rise from bottom
    vec3 local_pos = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
    
    // Center UVs around 0.5
    vec2 centered_uv = uv - 0.5;
    
    // Vertical gradient (0 at bottom, 1 at top)
    float height_gradient = uv.y;
    
    // Apply flame height stretch
    float stretched_height = pow(height_gradient, 1.0 / flame_height);
    
    // ---------- FLAME MOTION ----------
    
    // Rising motion - flames move upward
    float rise = t * 0.8;
    
    // Horizontal drift/sway
    float drift = sin(t * 1.5 + local_pos.y * 3.0) * horizontal_drift * 0.2;
    
    // 3D sampling position for noise
    vec3 sample_pos = vec3(
        (centered_uv.x + drift) * fire_scale,
        (height_gradient * flame_height - rise) * fire_scale,
        local_pos.z * fire_scale + t * 0.3
    );
    
    // ---------- TURBULENCE LAYERS ----------
    
    // Primary turbulence - defines flame shape
    float turb1 = fbm(sample_pos * 2.0 + vec3(0.0, -rise * 2.0, 0.0));
    
    // Secondary turbulence - adds detail
    float turb2 = fbm(sample_pos * 4.0 + vec3(drift * 2.0, -rise * 3.0, t));
    
    // Combine turbulence
    float turbulence_combined = mix(turb1, turb2, 0.4) * turbulence;
    
    // ---------- MULTI-FLAME LICKS (Teardrop Shapes Rising from Bottom) ----------
    
    float flame_mask = 0.0;
    
    // Generate multiple flame licks emanating upward from bottom
    for (int i = 0; i < flame_tongues; i++) {
        float flame_id = float(i);
        float flame_seed = flame_id * 73.152;
        
        // Each flame originates from the bottom edge at different X positions
        vec2 origin = vec2(
            (hash(vec3(flame_id, 0.0, 0.0)) - 0.5) * 1.0,  // Spread across bottom
            -0.5   // Bottom edge
        );
        
        // Flame-specific properties
        float flame_width = 0.15 + hash(vec3(flame_id, 2.0, 0.0)) * 0.15 * flame_variation;
        float flame_height_max = 0.6 + hash(vec3(flame_id, 3.0, 0.0)) * 0.7 * flame_variation;
        float flame_lean = (hash(vec3(flame_id, 4.0, 0.0)) - 0.5) * 0.4; // Lean direction
        
        // Time-based variation
        float time_offset = hash(vec3(flame_id, 5.0, 0.0)) * 6.28;
        float pulse = sin(t * 1.2 + time_offset) * 0.1 * flame_variation;
        
        // Current pixel position relative to origin
        vec2 from_origin = centered_uv - origin;
        
        // Apply lean - flame bends as it rises
        float lean_amount = from_origin.y * flame_lean;
        from_origin.x -= lean_amount;
        
        // Height from origin (0 at bottom, increases upward)
        float local_height = from_origin.y;
        
        // Only process pixels above the origin
        if (local_height > 0.0) {
            // Normalize height (0 to 1 over flame's height range)
            float norm_height = local_height / (flame_height_max + pulse);
            norm_height = clamp(norm_height, 0.0, 1.0);
            
            // Teardrop width profile:
            // Bottom (0.0): Medium width at ignition
            // Middle (0.3-0.5): widens to maximum
            // Top (1.0): tapers to flickering point
            float width_envelope;
            if (norm_height < 0.5) {
                // Widening phase - starts at base width, grows to max
                width_envelope = 0.6 + 0.4 * smoothstep(0.0, 0.5, norm_height);
            } else {
                // Tapering phase - narrows to point
                width_envelope = 1.0 * (1.0 - smoothstep(0.5, 1.0, norm_height));
            }
            
            // Apply width envelope to base width
            float current_width = flame_width * max(width_envelope, 0.1);
            
            // Horizontal distance from flame centerline
            float horiz_dist = abs(from_origin.x);
            
            // Create smooth teardrop shape
            float shape = 1.0 - smoothstep(
                current_width * (1.0 - flame_separation * 0.5),
                current_width * (1.0 + flame_separation),
                horiz_dist
            );
            
            // Vertical fade - SOLID at bottom (origin), FADES at top
            // Strong presence near origin, diminishes as it rises
            float vert_fade = (1.0 - pow(norm_height, tip_fadeout * 0.8)) * smoothstep(0.0, 0.03, norm_height);
            
            // Combine shape and vertical fade
            float flame_lick = shape * vert_fade;
            
            // Add irregularity using noise
            float irregular = fbm(vec3(
                from_origin.x * 10.0 + flame_seed,
                norm_height * 8.0 - rise * 2.0,
                t * 0.7 + flame_seed
            ));
            
            // Apply irregularity to break up perfect shapes
            flame_lick *= (0.7 + 0.3 * irregular);
            flame_lick += (irregular - 0.5) * flame_irregularity * 0.2;
            flame_lick = clamp(flame_lick, 0.0, 1.0);
            
            // Blend this flame into total
            flame_mask = max(flame_mask, flame_lick);
        }
    }
    
    // Apply global turbulence for wavering
    flame_mask += (turbulence_combined - 0.5) * 0.35;
    flame_mask = clamp(flame_mask, 0.0, 1.0);
    
    // Add bright core areas
    float radial = length(centered_uv) * 1.8;
    float core = smoothstep(0.6, 0.0, radial) * core_density * flame_mask;
    flame_mask = clamp(flame_mask + core * 0.4, 0.0, 1.0);
    
    // Very soft edges that fade smoothly to nothing
    flame_mask = smoothstep(edge_softness * 0.5, 1.0 - edge_softness * 0.05, flame_mask);
    
    // ---------- FLICKERING ----------
    
    // Pulsing variation
    float flicker = 1.0 + sin(t * flicker_speed) * flicker_amount * 0.5;
    flicker += sin(t * flicker_speed * 1.7 + 1.2) * flicker_amount * 0.3;
    flame_mask *= flicker;
    
    // ---------- COLOR TEMPERATURE ----------
    
    // Temperature gradient based on height and turbulence
    float temp = stretched_height + turbulence_combined * 0.3;
    
    // Add color variation noise
    float color_noise = fbm(sample_pos * 3.0 + vec3(t * 0.5, 0.0, 0.0));
    temp += (color_noise - 0.5) * color_variation;
    
    // Map temperature to color
    vec3 fire_color;
    if (temp < 0.3) {
        // Dark ember to red
        fire_color = mix(ember_color, fire_color_base, temp / 0.3);
    } else if (temp < 0.7) {
        // Red to orange
        fire_color = mix(fire_color_base, fire_color_mid, (temp - 0.3) / 0.4);
    } else {
        // Orange to bright yellow-white
        fire_color = mix(fire_color_mid, fire_color_hot, (temp - 0.7) / 0.3);
    }
    
    // Apply intensity
    flame_mask *= fire_intensity;
    
    // ---------- OUTPUT ----------
    
    // Emissive fire color
    EMISSION = fire_color * flame_mask * emissive_power;
    
    // Alpha for blending
    ALPHA = clamp(flame_mask, 0.0, 1.0);
    
    // Set albedo (in blend_add mode, emission dominates)
    ALBEDO = fire_color;
}
