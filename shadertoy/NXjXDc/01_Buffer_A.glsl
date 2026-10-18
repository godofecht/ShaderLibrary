#define PI  3.14159265358979323846
#define TAU 6.28318530717958647692

#define GAZE_RESPONSE 1.15
#define PREY_RESPONSE 0.82
#define MEMORY_DECAY  0.985
#define FEAR_RISE     0.115
#define FEAR_FALL     0.012
#define OPEN_RISE     0.055
#define OPEN_FALL     0.009

float sat(float x)
{
    return clamp(x, 0.0, 1.0);
}

float impulse(float center, float width, float x)
{
    float d = (x - center) / width;
    return exp(-d * d);
}

float hash12(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
    q += dot(q, q.yzx + 19.19);
    return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i + vec2(0.0, 0.0));
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 5; ++i)
    {
        v += a * noise2(p);
        p = mat2(1.62, 1.11, -1.11, 1.62) * p + vec2(17.13, -9.21);
        a *= 0.5;
    }

    return v;
}

vec2 observerUV(float t)
{
    vec2 idle = vec2(
        0.5 + 0.24 * sin(t * 0.113 + sin(t * 0.031) * 2.0),
        0.5 + 0.19 * cos(t * 0.097 + sin(t * 0.043) * 1.7)
    );

    vec2 mouse = iMouse.xy / iResolution.xy;
    float actives = step(0.5, iMouse.z);

    return mix(idle, mouse, actives);
}

float sourceLuma(vec2 uv)
{
    vec3 c = texture(iChannel1, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float localPreyEnergy(vec2 uv, vec2 px)
{
    float c = sourceLuma(uv);

    float l = sourceLuma(uv - vec2(px.x * 4.0, 0.0));
    float r = sourceLuma(uv + vec2(px.x * 4.0, 0.0));
    float u = sourceLuma(uv + vec2(0.0, px.y * 4.0));
    float d = sourceLuma(uv - vec2(0.0, px.y * 4.0));

    float contrast = abs(c - l) + abs(c - r) + abs(c - u) + abs(c - d);

    return sat(c * 0.68 + contrast * 1.95);
}

vec4 readMemory(vec2 uv, vec2 px)
{
    vec4 c = texture(iChannel0, uv) * 0.64;

    c += texture(iChannel0, uv + vec2( px.x, 0.0)) * 0.09;
    c += texture(iChannel0, uv + vec2(-px.x, 0.0)) * 0.09;
    c += texture(iChannel0, uv + vec2(0.0,  px.y)) * 0.09;
    c += texture(iChannel0, uv + vec2(0.0, -px.y)) * 0.09;

    return c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float t = iTime;

    vec4 prev = readMemory(uv, px);

    if (iFrame < 2)
    {
        prev = vec4(0.0);
    }

    vec2 gazeUV = observerUV(t);
    vec2 gazeP = gazeUV * 2.0 - 1.0;
    gazeP.x *= iResolution.x / iResolution.y;

    float gazeDist = length(gazeP - p);
    float gaze = exp(-gazeDist * gazeDist * 3.7);

    float prey = localPreyEnergy(uv, px);

    float hesitation = 0.5 + 0.5 * sin(
        t * 0.211 +
        prev.r * 5.7 +
        prev.g * 2.9 +
        prey * 2.6 +
        fbm2(uv * 3.0 + t * 0.03) * 2.0
    );

    hesitation = smoothstep(0.20, 0.92, hesitation);

    float threatTarget = sat(
        gaze * GAZE_RESPONSE +
        prey * PREY_RESPONSE * 0.52 +
        hesitation * 0.24
    );

    float fearTarget = sat(threatTarget + prev.g * 0.12);

    float fearRate = mix(FEAR_FALL, FEAR_RISE, step(prev.r, fearTarget));
    float fear = mix(prev.r, fearTarget, fearRate);

    float heartbeat = impulse(0.105, 0.022, fract(prev.b)) +
                      impulse(0.205, 0.034, fract(prev.b)) * 0.62;

    float openTarget = sat(
        pow(fear, 2.15) * 0.88 +
        prey * 0.24 +
        heartbeat * fear * 0.18
    );

    float openRate = mix(OPEN_FALL, OPEN_RISE, step(prev.g, openTarget));
    float opening = mix(prev.g, openTarget, openRate);

    float pulseSpeed = 0.0035 +
        fear * 0.012 +
        opening * 0.008 +
        prey * 0.003 +
        heartbeat * 0.002;

    float pulse = fract(prev.b + pulseSpeed);

    float lieTarget = sat(
        (1.0 - fear) * 0.30 +
        pow(opening, 3.25) * 0.72 +
        hesitation * 0.10
    );

    float lie = mix(prev.a, lieTarget, 0.014 + 0.036 * opening);

    float centreSoftness = smoothstep(0.04, 0.32, length(p));
    fear *= MEMORY_DECAY;
    opening *= mix(0.995, 1.0, centreSoftness);
    lie *= 0.997;

    fragColor = vec4(sat(fear), sat(opening), pulse, sat(lie));
}