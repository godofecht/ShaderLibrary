#define TAU 6.28318530718

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p)
{
    float n = hash12(p);
    return vec2(n, hash12(p + n + 19.19));
}

float vnoise(vec2 p)
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
    float a = 0.55;
    mat2 m = mat2(1.6, -1.2, 1.2, 1.6);

    for (int i = 0; i < 4; i++)
    {
        v += a * vnoise(p);
        p = m * p;
        a *= 0.5;
    }

    return v;
}

float field(vec2 p, float t)
{
    float f1 = fbm(p + vec2(0.07, -0.05) * t);
    float f2 = fbm(p * 1.8 - vec2(0.03, 0.08) * t);
    return 0.65 * f1 + 0.35 * f2;
}

vec2 curl2(vec2 p, float t)
{
    float e = 0.003;

    float fx1 = field(p + vec2(e, 0.0), t);
    float fx0 = field(p - vec2(e, 0.0), t);
    float fy1 = field(p + vec2(0.0, e), t);
    float fy0 = field(p - vec2(0.0, e), t);

    float dFdx = (fx1 - fx0) / (2.0 * e);
    float dFdy = (fy1 - fy0) / (2.0 * e);

    return vec2(dFdy, -dFdx);
}

vec2 advect(vec2 p, float t, float freq, float strength)
{
    vec2 q = p * freq;
    vec2 v = curl2(q, t);
    return p + v * (strength / freq);
}

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 glitterPalette(float x)
{
    vec3 c0 = vec3(0.95, 0.95, 1.00);
    vec3 c1 = vec3(1.00, 0.86, 0.45);
    vec3 c2 = vec3(0.65, 0.90, 1.00);
    vec3 c3 = vec3(1.00, 0.55, 0.82);
    vec3 c4 = vec3(0.85, 1.00, 0.70);

    vec3 col = c0;
    col = mix(col, c1, smoothstep(0.05, 0.25, x));
    col = mix(col, c2, smoothstep(0.28, 0.48, x));
    col = mix(col, c3, smoothstep(0.52, 0.72, x));
    col = mix(col, c4, smoothstep(0.76, 0.96, x));

    return col;
}

float sparkleShape(vec2 p, float twinkle)
{
    float r2 = dot(p, p);
    float core = exp(-220.0 * r2);

    float sx = exp(-70.0 * abs(p.x) - 22.0 * abs(p.y));
    float sy = exp(-70.0 * abs(p.y) - 22.0 * abs(p.x));

    float d1 = exp(-95.0 * abs(p.x + p.y));
    float d2 = exp(-95.0 * abs(p.x - p.y));

    float cross = max(sx, sy);
    float diag = max(d1, d2);

    float glitter = core + (0.35 + 1.65 * twinkle) * cross + 0.25 * twinkle * diag;
    return glitter;
}

vec3 renderGlitterLayer(vec2 uv, float layer, float t)
{
    vec3 accum = vec3(0.0);

    float density = mix(12.0, 34.0, layer);
    vec2 g = uv * density;
    vec2 cell = floor(g);

    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            vec2 cid = cell + vec2(float(i), float(j)) + vec2(29.0 * layer, 17.0 * layer);
            vec2 rnd = hash22(cid + 13.7 * layer);

            vec2 center = (cid + 0.08 + 0.84 * rnd) / density;
            center = advect(center, t * (0.45 + 0.12 * rnd.x) + 9.0 * rnd.y, 3.0 + 1.5 * layer, 0.20 + 0.05 * layer);
            center += 0.012 * vec2
            (
                sin(t * (0.8 + 0.6 * rnd.y) + rnd.x * TAU),
                cos(t * (0.9 + 0.5 * rnd.x) + rnd.y * TAU)
            );

            vec2 p = uv - center;

            float ang = rnd.x * TAU + 0.8 * field(center * 3.0 + rnd * 2.0, t);
            p = rot(ang) * p;

            float size = mix(0.0045, 0.0125, rnd.y) * mix(1.15, 0.52, layer);
            p /= size;

            float twinkle =
                0.5 + 0.5 * sin
                (
                    t * (5.0 + 8.0 * rnd.x)
                    + rnd.y * TAU
                    + 7.0 * field(center * 2.4 + rnd * 5.0, t * 0.7)
                );

            twinkle = pow(twinkle, 5.0);

            float s = sparkleShape(p, twinkle);

            float falloff = 1.0 - smoothstep(1.05, 1.75, length(center));
            float visibility = smoothstep(0.22, 0.95, field(center * 1.7, t * 0.6));
            float intensity = s * falloff * (0.20 + 0.80 * visibility);

            float cx =
                fract
                (
                    rnd.x
                    + 0.18 * rnd.y
                    + 0.08 * t
                    + 0.22 * field(center * 2.2 + rnd * 4.0, t)
                );

            vec3 col = glitterPalette(cx);

            float whiteHot = smoothstep(1.4, 2.8, s);
            col = mix(col, vec3(1.0), 0.55 * whiteHot);

            accum += col * intensity;
        }
    }

    return accum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime;

    vec3 col = vec3(0.006, 0.007, 0.010);

    float haze = fbm(uv * 3.0 - vec2(0.05, 0.03) * t);
    col += 0.018 * vec3(0.7, 0.8, 1.0) * haze;

    for (int layerIndex = 0; layerIndex < 7; layerIndex++)
    {
        float layer = float(layerIndex) / 6.0;
        col += renderGlitterLayer(uv, layer, t);
    }

    float dust = fbm(advect(uv * 5.5, t * 0.35, 4.0, 0.08) * 8.0 + 0.3 * t);
    col += 0.06 * vec3(1.0, 0.95, 0.85) * pow(smoothstep(0.78, 1.0, dust), 2.0);

    vec2 q = advect(uv * 1.2, t * 0.3, 2.2, 0.14);
    float glow = exp(-1.8 * dot(q, q));
    col += 0.10 * vec3(0.5, 0.6, 0.9) * glow;

    col = 1.0 - exp(-1.25 * col);

    float vig = smoothstep(1.5, 0.15, length(uv));
    col *= mix(0.70, 1.05, vig);

    col = pow(col, vec3(0.92));

    fragColor = vec4(col, 1.0);
}