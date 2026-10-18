#define PI 3.141592653589
#define ITER_BASE 2.1
#define ITER_MAX floor(log(iResolution.y) / log(ITER_BASE))

#define rand(p)     fract(sin(dot(p, vec3(12.9898, 78.233, 3.1415))) * 43758.5453)
#define roundv(v,m) round(v * m) / m

vec2 render(vec3 p)
{
    float result = 0.0;
    float threshold = 0.75;

    int i = 2;
    for (; i < int(ITER_MAX + 4.0) && result < threshold; i++)
    {
        float m = pow(ITER_BASE, float(i));
        result = roundv(rand(roundv(p, m)), 2.0);
    }

    return vec2(1.0 - result, float(i) / float(ITER_MAX));
}

mat2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

vec2 blockify(vec2 p, float cells)
{
    return (floor(p * cells) + 0.5) / cells;
}

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(
        6.2831853 *
        (
            vec3(0.00, 0.23, 0.61) +
            t * vec3(1.00, 1.17, 1.31)
        )
    );
}

vec2 centerSafeWarp(vec2 uv, float t)
{
    float r = length(uv);

    float centerFade = smoothstep(0.0, 0.45, r);

    float swirl =
        0.18 *
        sin(t * 0.7 + r * 4.0) *
        centerFade;

    uv = rot(swirl) * uv;

    float pulse =
        1.0 +
        0.06 *
        sin(r * 8.0 - t * 2.1) *
        centerFade;

    uv *= pulse;

    vec2 wobble = vec2(
        sin(uv.y * 5.5 + t * 1.6),
        cos(uv.x * 6.5 - t * 1.4)
    );

    uv += 0.045 * wobble * centerFade;

    vec2 shear = vec2(
        sin((uv.x + uv.y) * 4.0 + t * 1.2),
        cos((uv.x - uv.y) * 4.5 - t * 1.1)
    );

    uv += 0.025 * shear * centerFade;

    return uv;
}

vec3 blockLayer(vec2 uv, float t, float ghostIndex, float cells)
{
    vec2 ghostDrift = 0.045 * ghostIndex * vec2(
        sin(t * 1.4 + ghostIndex * 1.7),
        cos(t * 1.1 - ghostIndex * 1.3)
    );

    vec2 q = centerSafeWarp(uv + ghostDrift, t);

    q = blockify(q, cells);

    vec2 rr = render(vec3(
        q.x + t * 0.10,
        q.y + sin(t * 0.3) * 0.05,
        t * 0.10 + ghostIndex * 0.13
    ));

    float v = rr.x;
    float depth = rr.y;

    float cellRand = rand(vec3(q * cells, ghostIndex + floor(t * 3.0)));

    vec3 col = palette(
        depth * 0.65 +
        v * 0.75 +
        ghostIndex * 0.10 +
        cellRand * 0.25 +
        t * 0.06
    );

    float flicker = 0.75 + 0.45 * sin(t * 5.0 + cellRand * 8.0 + ghostIndex);

    col *= mix(0.28, 1.55, v);
    col *= flicker;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy * 2.0 - iResolution.xy) / iResolution.y;

    float mouseZoom = (iMouse.x > 0.0)
        ? (iMouse.x / iResolution.x * 2.0 + 1.0)
        : 1.35;

    uv *= mouseZoom;

    float t = iTime;

    uv *= 1.0 + 0.035 * sin(t * 1.2);
    uv = rot(0.025 * sin(t * 0.75)) * uv;

    float cells = 38.0 + 8.0 * sin(t * 0.35);

    vec3 col = vec3(0.0);

    vec2 ca = 0.018 * vec2(
        sin(t * 1.7),
        cos(t * 1.35)
    );

    for (int i = 0; i < 7; i++)
    {
        float fi = float(i);
        float tt = t - fi * 0.085;

        vec3 r = blockLayer(uv + ca, tt + 0.025, fi, cells);
        vec3 g = blockLayer(uv,      tt,         fi, cells);
        vec3 b = blockLayer(uv - ca, tt - 0.025, fi, cells);

        vec3 ghost = vec3(r.r, g.g, b.b);

        float weight = exp(-fi * 0.34);
        col += ghost * weight;
    }

    vec2 blockUV = blockify(uv, cells);

    float r = length(uv);
    float br = length(blockUV);

    vec3 feverGlow = palette(t * 0.14 + br * 0.55);
    col += 0.22 * feverGlow * exp(-br * 2.9) * (0.5 + 0.5 * sin(t * 4.0));

    vec2 gridUV = abs(fract(uv * cells) - 0.5);
    float gridEdge = max(gridUV.x, gridUV.y);
    float gridLine = smoothstep(0.455, 0.5, gridEdge);

    col *= 0.90 + 0.18 * gridLine;

    float scan = 0.965 + 0.035 * sin(fragCoord.y * 2.0 + t * 18.0);
    col *= scan;

    col *= 1.08 - 0.28 * smoothstep(0.2, 1.75, r);

    col = tanh(col * 0.92);

    fragColor = vec4(col, 1.0);
}