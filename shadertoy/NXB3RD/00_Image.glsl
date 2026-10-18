
#define PI  3.14159265359
#define TAU 6.28318530718

const float QC_SCALE = 128.0;

float NOISE_SCALE_VARIATION = 0.5;
float SPEED = 0.04;
float LOOP_LENGTH = 3.0;
float LOOP_NOISE_OFFSET_STRENGTH = 0.33;

#define SPEED_REL_LOOP (SPEED * LOOP_LENGTH)

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(TAU * (vec3(0.00, 0.33, 0.67) + t));
}

vec3 hash(vec3 p)
{
    p *= mat3(
         127.1, 311.7, -53.7,
         269.5, 183.3,  77.1,
        -301.7,  27.3, 215.3
    );

    return 2.0 * fract(sin(p) * 43758.5453123) - 1.0;
}

float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (6.0 * f - 15.0) + 10.0);

    return 2.0 * mix(
        mix(
            mix(dot(hash(i + vec3(0,0,0)), f - vec3(0,0,0)),
                dot(hash(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
            mix(dot(hash(i + vec3(0,1,0)), f - vec3(0,1,0)),
                dot(hash(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x),
            u.y
        ),
        mix(
            mix(dot(hash(i + vec3(0,0,1)), f - vec3(0,0,1)),
                dot(hash(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
            mix(dot(hash(i + vec3(0,1,1)), f - vec3(0,1,1)),
                dot(hash(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x),
            u.y
        ),
        u.z
    );
}

float turb(vec2 U, float t)
{
    float f = 0.0;
    float q = 1.0;
    float s = 0.0;

    float m = 1.5;

    for (int i = 0; i < 3; i++)
    {
        U += vec2(0.33);
        U -= t * vec2(0.6, 0.2);

        f += q * noise(vec3(U, t));
        s += q;

        q *= 0.5;
        U *= m;
        t *= 1.71;
    }

    return f / s;
}

vec2 hash22(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 phasorish(vec2 position, vec2 direction, float phaseOffset, float scaleVariation)
{
    vec2 p = position;
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    vec2 n00 = hash22(i + vec2(0, 0));
    vec2 n10 = hash22(i + vec2(1, 0));
    vec2 n01 = hash22(i + vec2(0, 1));
    vec2 n11 = hash22(i + vec2(1, 1));

    vec2 d00 = p - (i + vec2(0, 0));
    vec2 d10 = p - (i + vec2(1, 0));
    vec2 d01 = p - (i + vec2(0, 1));
    vec2 d11 = p - (i + vec2(1, 1));

    float a00 = dot(direction, d00) * (1.0 + scaleVariation * (2.0 * n00.y - 1.0)) + n00.x * TAU + phaseOffset;
    float a10 = dot(direction, d10) * (1.0 + scaleVariation * (2.0 * n10.y - 1.0)) + n10.x * TAU + phaseOffset;
    float a01 = dot(direction, d01) * (1.0 + scaleVariation * (2.0 * n01.y - 1.0)) + n01.x * TAU + phaseOffset;
    float a11 = dot(direction, d11) * (1.0 + scaleVariation * (2.0 * n11.y - 1.0)) + n11.x * TAU + phaseOffset;

    vec2 c00 = vec2(cos(a00), sin(a00));
    vec2 c10 = vec2(cos(a10), sin(a10));
    vec2 c01 = vec2(cos(a01), sin(a01));
    vec2 c11 = vec2(cos(a11), sin(a11));

    vec2 cx0 = mix(c00, c10, u.x);
    vec2 cx1 = mix(c01, c11, u.x);

    return mix(cx0, cx1, u.y);
}

vec2 computeNormal(vec2 V)
{
    return normalize(vec2(-V.y, V.x));
}

vec2 computeFlow(vec2 U, float eps)
{
    vec2 d = vec2(
        turb(U + vec2(0.0, -eps), 0.0) - turb(U + vec2(0.0, eps), 0.0),
        turb(U + vec2(eps, 0.0), 0.0) - turb(U + vec2(-eps, 0.0), 0.0)
    );

    d /= 2.0 * eps;
    d += vec2(1.0);

    return normalize(d);
}

vec2 trajectory(vec2 V, vec2 dVdx, vec2 dVdy, float t)
{
    mat2 A = mat2(dVdx.x, dVdy.x, dVdx.y, dVdy.y);
    return t * V + 0.5 * t * t * (A * V);
}

float sqr(float x)
{
    return x * x;
}

vec2 flowPhasor(vec2 U, vec2 fragCoord)
{
    float eps = 1e-3;

    vec2 V = computeFlow(U, eps);

    vec2 dVdx = (computeFlow(U + vec2(eps, 0.0), eps) - computeFlow(U - vec2(eps, 0.0), eps)) / (2.0 * eps);
    vec2 dVdy = (computeFlow(U + vec2(0.0, eps), eps) - computeFlow(U - vec2(0.0, eps), eps)) / (2.0 * eps);

    float o0 = fract(iTime / LOOP_LENGTH + LOOP_NOISE_OFFSET_STRENGTH * noise(vec3(0.005 * fragCoord, 0.05 * iTime)));
    float o1 = fract(o0 + 1.0 / 3.0);
    float o2 = fract(o0 + 2.0 / 3.0);

    float t0 = (o0 - 0.5) * 2.0;
    float t1 = (o1 - 0.5) * 2.0;
    float t2 = (o2 - 0.5) * 2.0;

    float m0 = 1.0 - abs(2.0 * o0 - 1.0);
    float m1 = 1.0 - abs(2.0 * o1 - 1.0);
    float m2 = 1.0 - abs(2.0 * o2 - 1.0);

    vec2 d0 = trajectory(V, dVdx, dVdy, SPEED_REL_LOOP * t0);
    vec2 d1 = trajectory(V, dVdx, dVdy, SPEED_REL_LOOP * t1);
    vec2 d2 = trajectory(V, dVdx, dVdy, SPEED_REL_LOOP * t2);

    vec2 n = computeNormal(V);

    vec2 n0 = computeNormal(V + dVdx * d0.x + dVdy * d0.y);
    vec2 n1 = computeNormal(V + dVdx * d1.x + dVdy * d1.y);
    vec2 n2 = computeNormal(V + dVdx * d2.x + dVdy * d2.y);

    n0 *= sqr(max(eps, dot(n0, n)));
    n1 *= sqr(max(eps, dot(n1, n)));
    n2 *= sqr(max(eps, dot(n2, n)));

    vec2 s0 = phasorish(20.0 * (U + d0),                         10.0 * n0, 0.0, NOISE_SCALE_VARIATION);
    vec2 s1 = phasorish(20.0 * (U + d1) + vec2(100.33, 0.33),     10.0 * n1, 0.0, NOISE_SCALE_VARIATION);
    vec2 s2 = phasorish(20.0 * (U + d2) + vec2(100.66, 100.66),   10.0 * n2, 0.0, NOISE_SCALE_VARIATION);

    return (m0 * s0 + m1 * s1 + m2 * s2) / (m0 + m1 + m2);
}

float quasicrystal(vec2 uv, float phase, out float chroma)
{
    float total = 0.0;
    chroma = 0.0;

    for (float i = 0.0; i < 7.0; i++)
    {
        float angle = PI * i / (10.0 + cos(7.0 * i) * 3.0);

        vec2 dir = vec2(cos(angle), sin(angle));
        float len = dot(uv, dir);

        float w = cos(2.0 * QC_SCALE * len + phase);

        total += 0.5 + 0.5 * w;
        chroma += sin(2.0 * QC_SCALE * len + phase + i * 1.7);
    }

    return 1.0 - abs(2.0 * fract(0.5 * total) - 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 R = iResolution.xy;

    vec2 uv = (fragCoord.yx - 0.5 * iResolution.yx) / min(iResolution.x, iResolution.y);

    if (abs(uv.x) > 0.5 || abs(uv.y) > 0.5)
    {
        fragColor = vec4(0.0);
        return;
    }

    vec2 U = fragCoord / R.y;
    U -= 0.5 * vec2(R.x / R.y, 1.0);

    vec2 ph = flowPhasor(U, fragCoord);
    vec2 V = computeFlow(U, 1e-3);

    float phasorPhase = atan(ph.y, ph.x);
    float phasorEnergy = length(ph);

    vec2 warped = uv;

    warped += 0.035 * ph;
    warped += 0.025 * V * sin(phasorPhase + iTime);
    warped += 0.012 * vec2(
        noise(vec3(uv * 3.0, iTime * 0.15)),
        noise(vec3(uv.yx * 3.0 + 17.0, iTime * 0.15))
    );

    float time = TAU * (iTime / 2.5);

    float chroma = 0.0;
    float pattern = quasicrystal(warped, time + 0.8 * phasorPhase, chroma);

    float waterLine = smoothstep(
        -0.3 * phasorEnergy + 2.2 * abs(0.75 * (U.x - U.y)) - 1.0,
         0.3 * phasorEnergy + 2.2 * abs(0.75 * (U.x - U.y)) - 1.0,
         ph.x
    );

    float hue = 0.11 * chroma
              + 0.19 * pattern
              + 0.18 * phasorPhase / TAU
              + 0.28 * length(uv)
              + 0.04 * iTime;

    vec3 color = palette(hue);

    color *= 0.28 + 1.25 * pattern;
    color += 0.35 * palette(hue + 0.22 + waterLine * 0.3) * waterLine;
    color += 0.15 * vec3(ph.x, ph.y, phasorEnergy);

    color = pow(max(color, 0.0), vec3(0.85));

    if (iMouse.z > 0.5)
    {
        color = 0.5 + 0.5 * vec3(ph.x, ph.y, sin(phasorPhase));
    }

    fragColor = vec4(color, 1.0);
}
