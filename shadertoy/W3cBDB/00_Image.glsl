//HEEHEE v2.0

vec3 palette(float t) {
    vec3 a = vec3(0.5);
    vec3 b = vec3(0.5);
    vec3 c = vec3(1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b * cos(6.28318 * (c * t + d));
}

mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float field(vec2 p) {
    float strength = 0.5 + 0.5 * sin(iTime * 0.3);
    float accum = 0.0;
    float prev = 0.0;
    float tw = 0.0;

    for (int i = 0; i < 6; i++) {
        float mag = dot(p, p);
        p = abs(p) / mag - 0.5;
        float w = exp(-float(i) / 2.0);
        accum += w * exp(-strength * pow(abs(mag - prev), 2.0));
        tw += w;
        prev = mag;
    }

    return max(0.0, accum / tw);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) /
              min(iResolution.x, iResolution.y);

    vec2 p = uv;

    float t = iTime * 0.15;

    float zoom = exp(sin(iTime * 0.2) * 0.5);
    p *= zoom;

    vec3 color = vec3(0.0);
    float amp = 1.0;

    for (int i = 0; i < 5; i++) {

        p *= rot(0.5 + float(i) * 0.2 + iTime * 0.1);

        float f = field(p);

        vec3 col = palette(f + float(i) * 0.2 + t);

        color += col * f * amp;

        p *= 1.6;
        amp *= 0.6;
    }

    color = pow(color, vec3(0.8));
    color = 1.0 - exp(-color * 1.2);

    fragColor = vec4(color, 1.0);
}
