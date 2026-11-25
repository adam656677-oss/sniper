shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float vignette = smoothstep(1.05, 0.18, distance(uv, vec2(0.48, 0.48)));
	float ridge = sin(uv.x * 13.0 + uv.y * 5.0) * 0.012;
	float horizon = smoothstep(0.72, 0.20, uv.y);
	float grain = fract(sin(dot(floor(uv * vec2(900.0, 520.0)), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 base = mix(vec3(0.012, 0.020, 0.022), vec3(0.075, 0.092, 0.086), horizon * 0.72);
	base += vec3(0.11, 0.055, 0.022) * smoothstep(0.95, 0.28, distance(uv, vec2(0.83, 0.32))) * 0.16;
	base += ridge * vec3(0.8, 0.75, 0.6);
	base += (grain - 0.5) * 0.012;
	base *= 0.48 + vignette * 0.52;
	COLOR = vec4(base, 1.0);
}
