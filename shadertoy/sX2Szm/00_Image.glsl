float band(float x, float center, float width)
{
    float a = smoothstep(center - width, center, x);
    float b = smoothstep(center, center + width, x);
    return a - b;
}

vec3 rampBands(float x)
{
    float w = 0.015;

    vec3 c0 = vec3(0.03, 0.02, 0.05);
    vec3 c1 = vec3(0.12, 0.06, 0.22);
    vec3 c2 = vec3(0.10, 0.35, 0.55);
    vec3 c3 = vec3(0.85, 0.35, 0.18);
    vec3 c4 = vec3(0.98, 0.90, 0.60);

    float b1 = smoothstep(0.20 - w, 0.20 + w, x);
    float b2 = smoothstep(0.45 - w, 0.45 + w, x);
    float b3 = smoothstep(0.70 - w, 0.70 + w, x);
    float b4 = smoothstep(0.88 - w, 0.88 + w, x);

    vec3 col = c0;
    col = mix(col, c1, b1);
    col = mix(col, c2, b2);
    col = mix(col, c3, b3);
    col = mix(col, c4, b4);

    col += 0.55 * band(x, 0.33, 0.006) * vec3(0.9, 0.95, 1.0);
    col += 0.35 * band(x, 0.61, 0.006) * vec3(0.2, 0.1, 0.0);
    col += 0.45 * band(x, 0.80, 0.005) * vec3(1.0, 0.7, 0.2);

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 centered = uv * 2.0 - 1.0;
    centered.x *= iResolution.x / iResolution.y;

    float c = texture(iChannel0, uv).r;

    float x = 1.0 - exp(-2.8 * c);
    x = pow(clamp(x, 0.0, 1.0), 0.9);

    vec3 col = rampBands(x);

    float highlight = pow(clamp(1.0 - abs(2.0 * x - 1.0), 0.0, 1.0), 8.0);
    col += 0.18 * highlight;

    float vig = smoothstep(1.35, 0.15, length(centered));
    col *= mix(0.82, 1.06, vig);

    col = pow(col, vec3(0.95));

    fragColor = vec4(col, 1.0);
}