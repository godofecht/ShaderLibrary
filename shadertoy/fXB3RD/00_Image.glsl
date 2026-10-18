#define PI 3.14159265359
const float scale = 128.;

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.00, 0.33, 0.67) + t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.yx - 0.5 * iResolution.yx) / min(iResolution.x, iResolution.y);

    if (abs(uv.x) > 0.5 || abs(uv.y) > 0.5)
    {
        fragColor = vec4(0.0);
        return;
    }

    float time = 2.0 * PI * (iTime / 2.5);

    float total = 0.0;
    float chroma = 0.0;

    for (float i = 0.0; i < 7.0; i++)
    {
        float angle = PI * i / (10.0 + cos(7.0 * i) * 3.0);

        vec2 dir = vec2(cos(angle), sin(angle));
        float len = dot(uv, dir);

        float wave = cos(2.0 * scale * len + time);
        total += (wave + 1.0) * 0.5;

        chroma += sin(2.0 * scale * len + time + i * 1.7);
    }

    float pattern = 1.0 - abs(2.0 * fract(0.5 * total) - 1.0);

    float hue = 0.12 * total
              + 0.08 * chroma
              + 0.35 * length(uv)
              + 0.05 * iTime;

    vec3 color = palette(hue);

    color *= 0.35 + 0.95 * pattern;
    color += 0.15 * palette(hue + pattern + 0.2) * pattern;

    fragColor = vec4(color, 1.0);
}