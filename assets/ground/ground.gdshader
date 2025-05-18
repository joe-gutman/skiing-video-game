shader_type canvas_item;

group_uniforms Main;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float height_min : hint_range(0.0, 1.0) = 0.0;
uniform float height_max : hint_range(0.0, 1.0) = 1.0;
uniform float slope_spacing : hint_range(0.1, 10.0) = 0.5;
uniform float slope_width : hint_range(0.01, 0.5) = 0.2;
uniform float wave_amplitude : hint_range(0.01, 1.0) = 0.2;
uniform float wave_frequency : hint_range(1.0, 10.0) = 5.0;
uniform vec2 texture_dimension;
uniform float texture_scale : hint_range(0.1, 100.0) = 1.0;

group_uniforms Edge;
uniform float edge_width : hint_range(0.01, 1.0) = 0.05;
uniform float edge_curve : hint_range(0.0, 2.0) = 2.0;

group_uniforms Normal;
uniform float normal_strength : hint_range(0.0, 100.0) = 1.0;

group_uniforms Position;
varying float height_map;
uniform vec2 world_pos;

vec3 get_normal_at(vec2 uv) {
    float dx = dFdx(height_map) * normal_strength;
    float dy = dFdy(height_map) * normal_strength;
    return normalize(vec3(dx, dy, 1.0));
}

void fragment() {
    // Convert world position to normalized texture coordinates
    vec2 world_uv = world_pos / texture_dimension;  // Convert world position to texture space

    // Compute the world-aligned UV coordinates and offset them based on the sprite's position
    vec2 uv = (UV + world_uv) / texture_scale;

    // Sine wave distortion
    float primary_distortion = sin(uv.y * wave_frequency) * wave_amplitude;
    float combined_distortion = primary_distortion;

    float band_position = mod(uv.x + combined_distortion, slope_spacing);
    float distance_from_black_center = abs(band_position - slope_spacing / 2.0);

    float blur_factor = pow(smoothstep(slope_width + edge_width, slope_width, distance_from_black_center), edge_curve);

    height_map = mix(height_min, height_max, blur_factor);
    vec3 normal = get_normal_at(uv);

    // Normal as color
    COLOR = mix(color, vec4(normal, 1.0), .5);
    NORMAL = normal;
}
