#define PI  3.14159265359
#define TAU 6.28318530718

const float scale = 128.0;

mat2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(TAU * (vec3(0.00, 0.33, 0.67) + t));
}

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 5; i++)
    {
        v += a * noise(p);
        p = rot(0.73) * p * 2.03 + 4.1;
        a *= 0.5;
    }

    return v;
}

vec2 angularHarmonic(vec2 p, float n)
{
    float r = length(p);
    float a = atan(p.y, p.x);

    return r * vec2(cos(n * a), sin(n * a));
}

vec2 continuousKaleido(vec2 p, float t)
{
    float m = 0.5 + 0.5 * sin(t * 0.23);

    vec2 k7  = angularHarmonic(p, 7.0);
    vec2 k9  = angularHarmonic(p, 9.0);
    vec2 k12 = angularHarmonic(p, 12.0);

    vec2 a = mix(k7, k9, smoothstep(0.0, 0.5, m));
    vec2 b = mix(k9, k12, smoothstep(0.5, 1.0, m));

    return mix(a, b, smoothstep(0.35, 0.65, m));
}

float sdBox(vec2 p, vec2 b)
{
    vec2 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float starField(vec2 uv)
{
    vec2 g = fract(uv * 80.0) - 0.5;
    vec2 id = floor(uv * 80.0);

    float h = hash12(id);
    float d = length(g);

    float star = smoothstep(0.035, 0.0, d) * step(0.985, h);
    star *= 0.5 + 0.5 * sin(iTime * 6.0 + h * TAU);

    return star;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    vec2 baseUV = uv;

    float t = iTime;
    float time = TAU * (t / 2.5);

    float morph = 0.5 + 0.5 * sin(t * 0.37);

    float circleSDF = length(baseUV) - 0.52;
    float squareSDF = sdBox(baseUV, vec2(0.47));
    float boundary = mix(circleSDF, squareSDF, morph);

    float mask = smoothstep(0.02, -0.01, boundary);
    float rim = exp(-abs(boundary) * 55.0);

    if (mask < 0.001)
    {
        fragColor = vec4(0.0);
        return;
    }

    vec2 warpA = vec2(
        fbm(uv * 4.0 + vec2(0.0, t * 0.21)),
        fbm(uv * 4.0 + vec2(8.7, -t * 0.19))
    );

    vec2 warpB = vec2(
        fbm(uv * 11.0 + warpA * 2.0 + t * 0.07),
        fbm(uv * 11.0 - warpA * 2.0 - t * 0.09)
    );

    uv += (warpA - 0.5) * 0.09;
    uv += (warpB - 0.5) * 0.035;

    uv = rot(0.18 * sin(t * 0.31)) * uv;

    vec2 kUV = continuousKaleido(uv, t);

    float total = 0.0;
    float chroma = 0.0;
    float sharp = 0.0;

    for (int i = 0; i < 11; i++)
    {
        float fi = float(i);

        float angle = PI * fi / (10.0 + cos(7.0 * fi) * 3.0);
        angle += 0.35 * sin(t * 0.21 + fi * 1.83);

        vec2 dir = vec2(cos(angle), sin(angle));

        float lenA = dot(kUV, dir);
        float lenB = dot(uv, rot(fi * 0.47) * dir);

        float phase = time + fi * 1.7;

        float waveA = cos(2.0 * scale * lenA + phase);
        float waveB = sin(1.13 * scale * lenB - phase * 0.73);

        float wave = mix(waveA, waveB, 0.35 + 0.25 * sin(t + fi));

        total += (wave + 1.0) * 0.5;
        chroma += sin(2.0 * scale * lenA + phase + fi * 0.91);

        sharp += pow(abs(wave), 18.0);
    }

    float pattern = 1.0 - abs(2.0 * fract(0.5 * total) - 1.0);
    float plasma = fbm(kUV * 9.0 + chroma * 0.015 + t * 0.1);

    float rings = sin(90.0 * length(uv) - t * 5.0 + plasma * 5.0);
    rings = 0.5 + 0.5 * rings;

    float lightning = pow(pattern, 2.7) + 0.18 * sharp;
    float glow = exp(-3.2 * length(baseUV)) * (0.45 + 0.75 * pattern);

    float hue = 0.12 * total
              + 0.08 * chroma
              + 0.35 * length(uv)
              + 0.25 * plasma
              + 0.06 * rings
              + 0.05 * t;

    vec3 color = palette(hue);

    vec3 secondary = palette(hue + 0.22 + 0.1 * sin(t));
    vec3 hot = palette(hue + pattern + 0.45);

    color *= 0.18 + 1.25 * pattern;
    color += secondary * rings * 0.25;
    color += hot * lightning * 0.35;
    color += palette(hue + 0.75) * rim * 0.55;
    color += starField(baseUV + warpA * 0.04) * palette(hue + 0.4) * 1.5;

    color *= 0.72 + 0.55 * glow;

    float vignette = smoothstep(0.85, 0.15, length(baseUV));
    color *= vignette * mask;

    color = pow(color, vec3(0.82));

    fragColor = vec4(color, 1.0);
}