shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += noise2(p) * amplitude;
        p *= 2.03;
        amplitude *= 0.5;
    }
    return value;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_position.xz;
    float broad = fbm(p * 0.035);
    float medium = fbm(p * 0.19);
    float grain = noise2(p * 1.7);
    float stone_mask = smoothstep(0.56, 0.78, broad * 0.72 + medium * 0.28);
    vec3 earth = vec3(0.19, 0.205, 0.16);
    vec3 dry_soil = vec3(0.29, 0.255, 0.19);
    vec3 rock = vec3(0.30, 0.30, 0.265);
    vec3 ground = mix(earth, dry_soil, smoothstep(0.40, 0.68, broad));
    ground = mix(ground, rock, stone_mask * 0.72);
    ground *= 0.88 + grain * 0.22;
    ALBEDO = ground;
    ROUGHNESS = 0.96;
    METALLIC = 0.0;
}
