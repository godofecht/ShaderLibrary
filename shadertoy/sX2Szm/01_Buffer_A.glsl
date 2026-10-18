#define TAU 6.28318530718

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
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
    float a = 0.5;
    mat2 m = mat2(1.6, -1.2, 1.2, 1.6);

    for (int i = 0; i < 6; i++)
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
    float e = 0.002;

    float fx1 = field(p + vec2(e, 0.0), t);
    float fx0 = field(p - vec2(e, 0.0), t);
    float fy1 = field(p + vec2(0.0, e), t);
    float fy0 = field(p - vec2(0.0, e), t);

    float dFdx = (fx1 - fx0) / (2.0 * e);
    float dFdy = (fy1 - fy0) / (2.0 * e);

    return vec2(dFdy, -dFdx);
}

float sourceBlob(vec2 uv, vec2 pos, float radius)
{
    float d = length(uv - pos);
    return exp(-d * d / (radius * radius));
}

vec2 uvToWorld(vec2 uv, vec2 res)
{
    return (uv * res - 0.5 * res) / res.y;
}

vec2 worldToUV(vec2 p, vec2 res)
{
    return (p * res.y + 0.5 * res) / res;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    vec2 px = 1.0 / res;

    if (iFrame < 2)
    {
        float seed = 0.0;
        seed += sourceBlob(uv, vec2(0.35, 0.50), 0.035);
        seed += sourceBlob(uv, vec2(0.65, 0.50), 0.035);
        seed += sourceBlob(uv, vec2(0.50, 0.35), 0.025);
        seed += sourceBlob(uv, vec2(0.50, 0.65), 0.025);
        fragColor = vec4(seed, 0.0, 0.0, 1.0);
        return;
    }

    float t = iTime;

    vec2 p = uvToWorld(uv, res);

    float flowFreq = 3.0;
    float flowStrength = 0.18;
    float dt = 1.0;

    vec2 vel = curl2(p * flowFreq, t * 0.9);
    vec2 backP = p - vel * flowStrength * dt;
    vec2 backUV = clamp(worldToUV(backP, res), 0.0, 1.0);

    float c  = texture(iChannel0, backUV).r;
    float l  = texture(iChannel0, clamp(backUV - vec2(px.x, 0.0), 0.0, 1.0)).r;
    float r  = texture(iChannel0, clamp(backUV + vec2(px.x, 0.0), 0.0, 1.0)).r;
    float d  = texture(iChannel0, clamp(backUV - vec2(0.0, px.y), 0.0, 1.0)).r;
    float u  = texture(iChannel0, clamp(backUV + vec2(0.0, px.y), 0.0, 1.0)).r;

    float lap = l + r + d + u - 4.0 * c;

    float D = 0.14;
    float next = c + D * lap;

    next *= 0.9992;

    vec2 movingSource = 0.5 + 0.22 * vec2(cos(iTime * 0.43), sin(iTime * 0.61));
    next += 0.010 * sourceBlob(uv, movingSource, 0.020);

    if (iMouse.z > 0.0)
    {
        vec2 m = iMouse.xy / res;
        next += 0.060 * sourceBlob(uv, m, 0.030);
    }

    next = clamp(next, 0.0, 10.0);

    fragColor = vec4(next, 0.0, 0.0, 1.0);
}