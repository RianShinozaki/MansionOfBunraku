shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_draw_opaque;

uniform samplerCube cubemap;
uniform vec3 rotate;

varying vec3 pos;

mat3 rotateX(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(1, 0, 0),
        vec3(0, c, -s),
        vec3(0, s, c)
    );
}

// Rotation matrix around the Y axis.
mat3 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );
}

// Rotation matrix around the Z axis.
mat3 rotateZ(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, -s, 0),
        vec3(s, c, 0),
        vec3(0, 0, 1)
    );
}

void vertex() {
    pos = VERTEX;
    // Called for every vertex the material is visible on.
}

void fragment() {
    vec3 dif = normalize(pos - CAMERA_POSITION_WORLD);
    dif = dif * rotateX(rotate.x*TIME) * rotateY(rotate.y*TIME) * rotateZ(rotate.z*TIME);
    ALBEDO = texture(cubemap, dif).rgb;
    // Called for every pixel the material is visible on.
}

//void light() {
//    // Called for every pixel for every light affecting the material.
//    // Uncomment to replace the default light processing function with this one.
//}