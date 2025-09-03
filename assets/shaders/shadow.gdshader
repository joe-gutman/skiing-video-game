shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float shadow_strength : hint_range(0.0, 1.0);
uniform float shadow_skew : hint_range(0.0, 1.0);
uniform float hue_shift : hint_range(-1.0, 1.0);
uniform float saturation_multiplier : hint_range(0.0, 2.0);

// ---- RGB <-> HSV helpers
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0., -1./3., 2./3., -1.);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1., 2./3., 1./3., 3.);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6. - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0., 1.), c.y);
}
vec3 overlay_blend(vec3 base, vec3 blend) {
    vec3 result;
    for (int i = 0; i < 3; i++) {
        if (base[i] < 0.5)
            result[i] = 2.0 * base[i] * blend[i];
        else
            result[i] = 1.0 - 2.0 * (1.0 - base[i]) * (1.0 - blend[i]);
    }
    return result;
}

void fragment() {
    vec4 bg_color = texture(screen_texture, SCREEN_UV);

    // Apply skew to the mask sampling
    vec2 mask_uv = UV;
    mask_uv.x += shadow_skew * (mask_uv.y - 0.5); // Center-based skew
    mask_uv = clamp(mask_uv, 0.0, 1.0); // Prevent out-of-bounds errors

    vec4 mask_color = texture(TEXTURE, mask_uv);
    float mask_alpha = mask_color.a * shadow_strength;

    vec3 hsv = rgb2hsv(bg_color.rgb);
    hsv.x = fract(hsv.x + hue_shift);
    hsv.y = clamp(hsv.y * saturation_multiplier, 0.0, 1.0);
    hsv.z *= (1.0 - shadow_strength);

    vec3 shadow_rgb = hsv2rgb(hsv);
    vec3 overlay_rgb = overlay_blend(bg_color.rgb, shadow_rgb);

    vec3 final_rgb = mix(bg_color.rgb, overlay_rgb, mask_alpha);
    COLOR = vec4(final_rgb, bg_color.a);
}
