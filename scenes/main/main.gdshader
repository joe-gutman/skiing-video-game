shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float width = 1.0;
uniform bool addDepth = false; // Kept for compatibility, but not used
uniform vec2 viewport_size; // Pass this from a script

vec3 overlay(vec3 base, vec3 blend) {
    return mix(2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend), clamp(base, 0.0, 1.0));
}

float textureCavity(sampler2D screen_texture, vec2 uv, vec2 pixel_size) {
    vec3 color = texture(screen_texture, uv).rgb;
    float r_off = texture(screen_texture, uv - vec2(pixel_size.x * width, 0)).r;
    float g_off = texture(screen_texture, uv + vec2(0, pixel_size.y * width)).g;
    return (color.r - r_off) + (color.g - g_off) + 0.5;
}

void fragment() {
    vec4 origin = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec2 pixel_size = 1.0 / viewport_size;  // Now using the uniform

    float res = textureCavity(SCREEN_TEXTURE, SCREEN_UV, pixel_size);

    COLOR = vec4(overlay(origin.rgb, vec3(res)), origin.a);
}
