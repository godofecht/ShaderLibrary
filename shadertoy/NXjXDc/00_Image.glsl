#define PI  3.14159265358979323846
#define TAU 6.28318530717958647692

#define LIFE_RATE        1.00
#define BREATH_RATE      0.54
#define HEART_RATE       0.82
#define BREATH_AMOUNT    0.92
#define HEART_AMOUNT     0.78
#define CHAOS_AMOUNT     0.76
#define TWITCH_AMOUNT    0.34
#define LIE_AMOUNT       0.64
#define TRANSFER_START   0.18
#define TRANSFER_END     0.58
#define ORGANIC_COLOR    0.82
#define NERVE_GAIN       1.12
#define MEMBRANE_GAIN    1.04
#define RIPPLE_GAIN      1.08

#define GAZE_RESPONSE    1.15
#define PREY_RESPONSE    0.82
#define FLARE_AMOUNT     1.05
#define FOLDING_AMOUNT   0.88
#define WATCHFULNESS     0.94
#define THREAT_MEMORY    0.78
#define CLOTH_REALISM    0.86

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float sat(float x)
{
    return clamp(x, 0.0, 1.0);
}

vec2 sat(vec2 x)
{
    return clamp(x, 0.0, 1.0);
}

vec3 sat(vec3 x)
{
    return clamp(x, 0.0, 1.0);
}

float impulse(float center, float width, float x)
{
    float d = (x - center) / width;
    return exp(-d * d);
}

float breathSignal(float t)
{
    return 0.5 + 0.5 * sin(
        t * BREATH_RATE +
        0.23 * sin(t * 0.173) +
        0.07 * sin(t * 2.13)
    );
}

float heartSignal(float t)
{
    float x = fract(t * HEART_RATE);

    float a = impulse(0.105, 0.022, x);
    float b = impulse(0.205, 0.034, x);
    float c = impulse(0.625, 0.115, x);

    return sat(a + 0.62 * b + 0.16 * c);
}

float chaosSignal(float t)
{
    float x = 0.5 + 0.5 * sin(t * 0.137 + sin(t * 0.031) * 2.0);

    for (int i = 0; i < 8; ++i)
    {
        float fi = float(i);
        x = 0.5 + 0.5 * sin(
            x * (2.73 + fi * 0.173) +
            t * (0.217 + fi * 0.029) +
            sin(t * (0.071 + fi * 0.011) + fi * 1.91)
        );
    }

    return x;
}

float lieSignal(float t, float r, float chaos)
{
    float slow = 0.5 + 0.5 * sin(t * 0.191 + chaos * TAU + sin(t * 0.047) * 3.0);
    float mask = smoothstep(0.24, 1.15, r);
    float conceal = 1.0 - smoothstep(0.36, 0.84, slow);
    float eruption = pow(slow, 7.0);

    return sat((conceal * 0.18 + eruption) * mask);
}

vec4 livingState(float t, float r)
{
    float chaos = chaosSignal(t);
    float breath = breathSignal(t + chaos * 0.37);
    float heart = heartSignal(t + 0.18 * chaos + breath * 0.05);
    float lie = lieSignal(t, r, chaos);

    return vec4(breath, heart, chaos, lie);
}

vec2 observerUV(float t)
{
    vec2 idle = vec2(
        0.5 + 0.23 * sin(t * 0.113 + sin(t * 0.031) * 2.0),
        0.5 + 0.18 * cos(t * 0.097 + sin(t * 0.043) * 1.7)
    );

    vec2 mouse = iMouse.xy / iResolution.xy;
    float activess = step(0.5, iMouse.z);

    return mix(idle, mouse, activess);
}

float sourceLuma(vec2 uv)
{
    vec3 c = texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb;
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float localPreyEnergy(vec2 uv, vec2 px)
{
    float c  = sourceLuma(uv);
    float l  = sourceLuma(uv - vec2(px.x * 4.0, 0.0));
    float r  = sourceLuma(uv + vec2(px.x * 4.0, 0.0));
    float u  = sourceLuma(uv + vec2(0.0, px.y * 4.0));
    float d  = sourceLuma(uv - vec2(0.0, px.y * 4.0));

    float contrast = abs(c - l) + abs(c - r) + abs(c - u) + abs(c - d);
    return sat(c * 0.72 + contrast * 1.85);
}

vec4 attentionState(vec2 uv, vec2 p, vec2 px, float t)
{
    vec2 gazeUV = observerUV(t);
    vec2 gazeP = gazeUV * 2.0 - 1.0;
    gazeP.x *= iResolution.x / iResolution.y;

    vec2 toGaze = gazeP - p;
    float gazeDist = length(toGaze);

    float gaze = exp(-gazeDist * gazeDist * 3.4);
    float prey = localPreyEnergy(uv, px);

    float suspicion = 0.5 + 0.5 * sin(t * 0.19 + gaze * 2.8 + prey * 1.7);
    float hesitation = smoothstep(0.28, 0.78, suspicion);

    float threat = sat(
        gaze * GAZE_RESPONSE +
        prey * PREY_RESPONSE * 0.65 +
        hesitation * 0.28
    );

    float memory = sat(
        threat * 0.66 +
        THREAT_MEMORY * pow(0.5 + 0.5 * sin(t * 0.071 + threat * 5.0), 4.0)
    );

    float flarePulse = impulse(0.15, 0.055, fract(t * 0.37 + threat * 0.21));
    float flare = sat(pow(threat, 1.7) * (0.35 + 0.65 * flarePulse));

    return vec4(gaze, prey, memory, flare);
}

float transferMask(float r)
{
    float x = smoothstep(TRANSFER_START, TRANSFER_END, r);
    return x * x * (3.0 - 2.0 * x);
}

float coreMask(float r)
{
    return 1.0 - transferMask(r);
}

vec2 safeTransfer(vec2 original, vec2 transferred)
{
    float r = length(original);
    float m = transferMask(r);
    return mix(original, transferred, m);
}

vec2 cmul(vec2 a, vec2 b)
{
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 cdiv(vec2 a, vec2 b)
{
    float d = max(dot(b, b), 1e-6);
    return vec2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / d;
}

vec2 cinv(vec2 z)
{
    float d = max(dot(z, z), 1e-6);
    return vec2(z.x, -z.y) / d;
}

vec2 clogc(vec2 z)
{
    return vec2(log(length(z) + 1e-6), atan(z.y, z.x));
}

vec2 cexp(vec2 z)
{
    float e = exp(z.x);
    return e * vec2(cos(z.y), sin(z.y));
}

vec2 cpowc(vec2 z, float k)
{
    return cexp(clogc(z) * k);
}

vec2 csin(vec2 z)
{
    return vec2(sin(z.x) * cosh(z.y), cos(z.x) * sinh(z.y));
}

vec2 ccamera(vec2 z, float t)
{
    vec2 life = vec2(
        breathSignal(t) - 0.5,
        chaosSignal(t) - 0.5
    );

    vec2 a = vec2(0.72 + 0.08 * sin(t * 0.13), 0.31 * cos(t * 0.17));
    vec2 b = vec2(-0.38 + 0.05 * cos(t * 0.19), 0.47 + 0.04 * sin(t * 0.11));
    vec2 c = vec2(0.21 * sin(t * 0.07), -0.69 + 0.06 * cos(t * 0.15));
    vec2 d = vec2(0.86 + 0.03 * cos(t * 0.09), 0.18 * sin(t * 0.16));

    b += life * 0.035 * BREATH_AMOUNT;
    c += life.yx * 0.018 * CHAOS_AMOUNT;

    return cdiv(cmul(a, z) + b, cmul(c, z) + d);
}

float hash12(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
    q += dot(q, q.yzx + 19.19);
    return fract((q.x + q.y) * q.z);
}

float hash13(vec3 p)
{
    p = fract(p * vec3(0.1031, 0.11369, 0.13787));
    p += dot(p, p.yzx + 31.32);
    return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p)
{
    p = fract(p * vec3(0.1031, 0.11369, 0.13787));
    p += dot(p, p.yxz + 27.17);

    return fract(vec3(
        (p.x + p.y) * p.z,
        (p.x + p.z) * p.y,
        (p.y + p.z) * p.x
    ));
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

    for (int i = 0; i < 6; ++i)
    {
        v += a * noise2(p);
        p = mat2(1.62, 1.11, -1.11, 1.62) * p + vec2(17.13, -9.21);
        a *= 0.5;
    }

    return v;
}

float noise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);

    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, u.x);
    float x10 = mix(n010, n110, u.x);
    float x01 = mix(n001, n101, u.x);
    float x11 = mix(n011, n111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

float fbm3(vec3 p)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 6; ++i)
    {
        v += a * noise3(p);

        p = mat3(
             0.00,  1.60,  1.20,
            -1.60,  0.72, -0.34,
            -1.20, -0.34,  1.31
        ) * p;

        p += vec3(4.17, -2.91, 8.63);
        a *= 0.49;
    }

    return v;
}

vec3 hsv2rgb(vec3 c)
{
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), sat(p - 1.0), c.y);
}

vec3 tonemap(vec3 x)
{
    x = max(x, vec3(0.0));
    x = x * (2.51 * x + 0.03) / (x * (2.43 * x + 0.59) + 0.14);
    return sat(x);
}

vec2 barrel(vec2 uv, float k)
{
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + k * r2 + k * 0.18 * r2 * r2;
    return p * 0.5 + 0.5;
}

vec3 sourceCA(vec2 uv, vec2 dir, float amount)
{
    float r = texture(iChannel0, uv + dir * amount * 1.70).r;
    float g = texture(iChannel0, uv + dir * amount * 0.25).g;
    float b = texture(iChannel0, uv - dir * amount * 1.35).b;

    return vec3(r, g, b);
}

vec3 sourceBloom(vec2 uv, vec2 px)
{
    vec3 c = vec3(0.0);

    c += texture(iChannel0, uv + px * vec2( 1.0,  0.0)).rgb * 0.14;
    c += texture(iChannel0, uv + px * vec2(-1.0,  0.0)).rgb * 0.14;
    c += texture(iChannel0, uv + px * vec2( 0.0,  1.0)).rgb * 0.14;
    c += texture(iChannel0, uv + px * vec2( 0.0, -1.0)).rgb * 0.14;

    c += texture(iChannel0, uv + px * vec2( 2.0,  2.0)).rgb * 0.11;
    c += texture(iChannel0, uv + px * vec2(-2.0,  2.0)).rgb * 0.11;
    c += texture(iChannel0, uv + px * vec2( 2.0, -2.0)).rgb * 0.11;
    c += texture(iChannel0, uv + px * vec2(-2.0, -2.0)).rgb * 0.11;

    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    return c * smoothstep(0.42, 1.05, luma);
}

float cellular(vec3 p, out float cellId)
{
    vec3 g = floor(p);
    vec3 f = fract(p);

    float best = 100.0;
    cellId = 0.0;

    vec4 bio = livingState(iTime * LIFE_RATE, length(p.xy) * 0.18);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;

    for (int z = -1; z <= 1; ++z)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int x = -1; x <= 1; ++x)
            {
                vec3 o = vec3(float(x), float(y), float(z));
                vec3 h = hash33(g + o);

                vec3 q = o + 0.5 - f;

                float livingRate = 0.18 + 0.33 * h.z;
                float pulseBias = 1.0 + 0.28 * heart * HEART_AMOUNT;

                q += 0.43 * sin(
                    TAU * h +
                    iTime * LIFE_RATE * livingRate * pulseBias +
                    chaos * vec3(1.7, 2.1, 2.9)
                );

                q += 0.032 * BREATH_AMOUNT * (breath - 0.5) * sin(TAU * h.yzx + iTime * 0.31);

                float d = dot(q, q);

                if (d < best)
                {
                    best = d;
                    cellId = hash13(g + o + vec3(7.0, 13.0, 19.0));
                }
            }
        }
    }

    return sqrt(best);
}

vec2 manifoldFold(vec2 p, float t)
{
    vec4 bio = livingState(t, length(p));
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    p *= rot(0.17 * sin(t * 0.31) + 0.045 * CHAOS_AMOUNT * (chaos - 0.5));

    for (int i = 0; i < 8; ++i)
    {
        float fi = float(i);

        float livingScale = 1.0 + 0.025 * BREATH_AMOUNT * (breath - 0.5) + 0.018 * HEART_AMOUNT * heart;
        float twitch = TWITCH_AMOUNT * 0.018 * sin(t * (2.1 + fi * 0.37) + chaos * TAU + fi);

        p = abs(p);
        p = p / max(dot(p, p), 0.115 + 0.012 * heart);
        p -= vec2(
            0.74 + 0.045 * sin(t * 0.7 + fi) + twitch,
            0.53 + 0.035 * cos(t * 0.5 + fi * 1.7) - twitch * 0.7
        ) * livingScale;

        p *= rot(0.43 + 0.19 * sin(t * 0.21 + fi * 2.03) + lie * LIE_AMOUNT * 0.045);

        p += 0.045 * vec2(
            sin(p.y * 4.0 + t * 0.9 + fi + chaos),
            cos(p.x * 3.0 - t * 0.8 + fi - chaos)
        );
    }

    return p;
}

float complexOrbit(vec2 p, float t, out vec2 zOut, out float trap, out float phase)
{
    vec4 bio = livingState(t, length(p));
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    vec2 z = ccamera(p * (0.78 + 0.035 * BREATH_AMOUNT * (breath - 0.5)), t);

    vec2 c = vec2(
        -0.117 + 0.105 * sin(t * 0.113 + chaos * 0.9),
         0.745 + 0.075 * cos(t * 0.091 + breath * 0.5)
    );

    trap = 64.0;
    phase = 0.0;

    float escape = 0.0;

    for (int i = 0; i < 14; ++i)
    {
        float fi = float(i);

        vec2 z2 = cmul(z, z);

        vec2 pole = cinv(z + vec2(
            0.82 + 0.09 * sin(t * 0.13 + heart),
           -0.31 + 0.06 * cos(t * 0.19 + chaos)
        ));

        vec2 twist = csin(z.yx * vec2(0.73, -0.67) + vec2(t * 0.11, -t * 0.07));
        twist *= (0.043 + 0.012 * heart * HEART_AMOUNT) / (1.0 + dot(z, z));

        vec2 lied = vec2(-z.y, z.x) * lie * LIE_AMOUNT * 0.021;

        z = z2 + c + pole * 0.047 + twist + lied;
        z = mix(z, cpowc(z + vec2(0.025, -0.015), 1.06 + 0.015 * chaos * CHAOS_AMOUNT), 0.18);

        float m = dot(z, z);
        trap = min(trap, abs(z.x) + abs(z.y) + 0.22 * abs(sin(6.0 * atan(z.y, z.x))));
        phase += atan(z.y, z.x) * (0.11 + fi * 0.006 + heart * 0.002);

        if (m > 18.0 && escape == 0.0)
        {
            escape = fi / 14.0;
        }

        z = cdiv(z, vec2(
            1.0 + 0.018 * m,
            0.021 * sin(t * 0.17 + fi + lie * 2.0)
        ));
    }

    zOut = z;

    if (escape == 0.0)
    {
        escape = 1.0;
    }

    return escape;
}

float rippleField(vec2 p, float t, float complexPhase)
{
    float r = length(p);
    float a = atan(p.y, p.x);
    float transfer = transferMask(r);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    float n = fbm2(p * (3.7 + 0.6 * chaos) + vec2(t * 0.11, -t * 0.08));

    float pulseStretch = 1.0 + 0.08 * BREATH_AMOUNT * (breath - 0.5) + 0.05 * HEART_AMOUNT * heart;
    float shellA = sin((42.0 * pulseStretch) * r - t * 4.2 + 4.0 * n + complexPhase);
    float shellB = sin(27.0 * length(p - vec2(0.32 * sin(t * 0.31), 0.24 * cos(t * 0.27))) - t * 3.1);
    float shellC = sin(31.0 * length(p + vec2(0.21 * cos(t * 0.23), 0.29 * sin(t * 0.29))) - t * 3.7);

    float angular = sin(9.0 * a + 18.0 * r - t * 1.6 + n * 5.0 + lie * LIE_AMOUNT * 4.0);

    float ripple = shellA * 0.42 + shellB * 0.28 + shellC * 0.22 + angular * 0.08;
    ripple *= smoothstep(1.30, 0.08, r);
    ripple *= transfer;
    ripple *= RIPPLE_GAIN * (0.74 + 0.28 * breath + 0.26 * heart);

    return ripple;
}

vec2 rippleDisplace(vec2 p, float t, float complexPhase)
{
    float e = 0.0025;

    vec4 bio = livingState(t, length(p));
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    float c  = rippleField(p, t, complexPhase);
    float dx = rippleField(p + vec2(e, 0.0), t, complexPhase) - c;
    float dy = rippleField(p + vec2(0.0, e), t, complexPhase) - c;

    vec2 grad = vec2(dx, dy) / e;
    vec2 tangent = vec2(-grad.y, grad.x);

    vec2 involuntary = vec2(
        sin(t * 7.1 + chaos * 8.0),
        cos(t * 6.4 - chaos * 7.0)
    ) * heart * TWITCH_AMOUNT * 0.006;

    vec2 warped = p + grad * (0.010 + 0.004 * heart) + tangent * (0.0035 + 0.004 * lie) + involuntary;

    return safeTransfer(p, warped);
}

vec3 complexLayer(vec2 p, float t)
{
    vec2 z;
    float trap;
    float phase;

    float escape = complexOrbit(p, t, z, trap, phase);

    float r = length(p);
    float transfer = transferMask(r);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    float m = length(z);
    float a = atan(z.y, z.x);

    float orbitLine = exp(-7.0 * trap);
    float phaseBands = 0.5 + 0.5 * sin(phase * 5.0 + a * 9.0 - t * 1.2 + lie * 3.0);
    float contour = smoothstep(0.92, 1.0, phaseBands);
    float field = exp(-1.4 * m);

    vec3 base = hsv2rgb(vec3(
        fract(0.56 + 0.07 * a / TAU + 0.13 * escape + t * 0.011 + chaos * 0.035),
        0.76 + 0.08 * ORGANIC_COLOR,
        1.0 + 0.08 * breath
    ));

    vec3 hot = hsv2rgb(vec3(
        fract(0.08 + 0.18 * sin(phase * 0.7 + t * 0.21 + heart)),
        0.92,
        1.35 + 0.22 * heart
    ));

    vec3 cold = vec3(0.12, 0.46, 1.30) * (1.0 + lie * LIE_AMOUNT * 0.45);

    vec3 col = vec3(0.0);
    col += base * orbitLine * 1.25;
    col += hot * contour * field * 0.65;
    col += cold * pow(sat(1.0 - trap * 1.2), 4.0) * 0.42;

    return col * transfer;
}

vec3 manifoldLayer(vec2 p, float t)
{
    float r = length(p);
    float a = atan(p.y, p.x);
    float transfer = transferMask(r);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    vec2 z;
    float trap;
    float phase;

    complexOrbit(p * 0.83, t, z, trap, phase);

    float logR = log(r + 0.035);
    vec2 polar = vec2(a / TAU, logR);

    polar.x += 0.075 * sin(logR * 6.0 + t * 0.27 + phase * 0.05);
    polar.y += 0.060 * cos(a * 8.0 - t * 0.19 + length(z) * 0.3);

    polar *= 1.0 + 0.025 * BREATH_AMOUNT * (breath - 0.5);

    vec2 f = manifoldFold(polar * vec2(4.8, 2.9), t);

    float internal = fbm3(vec3(p * 2.2 + f * 0.15 + z * 0.035, t * 0.07 + chaos * 0.08));
    float id = 0.0;
    float c = cellular(vec3(f * 1.55 + z * 0.06, t * 0.16 + internal * 1.8), id);

    float membrane = smoothstep(0.105, 0.008, abs(c - 0.31 - 0.012 * breath + 0.007 * lie));
    float veinCore = sin(c * 42.0 - logR * 7.0 + t * 1.4 + internal * 4.0 + phase * 0.13 + heart * 2.0);
    float veins = pow(sat(veinCore * 0.5 + 0.5), 9.0 - 2.0 * heart);

    float script = sin(
        f.x * 19.0 +
        f.y * 31.0 +
        sin(f.x * 7.0 + t * 0.8 + z.x + lie) * 5.0 -
        cos(f.y * 6.0 - t * 0.6 + z.y - lie) * 4.0
    );

    script = smoothstep(0.955 - 0.025 * heart, 1.0, script);

    float iris = sin(88.0 * r - 13.0 * a + t * 2.7 + internal * 9.0 + phase * 0.21);
    iris = smoothstep(0.68, 1.0, iris) * smoothstep(1.15, 0.05, r);

    vec3 membraneCol = hsv2rgb(vec3(
        0.56 + 0.16 * id + 0.05 * sin(t + f.x) + ORGANIC_COLOR * 0.018 * breath,
        0.72 + 0.08 * ORGANIC_COLOR,
        1.05 + heart * 0.11
    ));

    vec3 veinCol = hsv2rgb(vec3(
        0.77 + 0.11 * sin(t * 0.4 + logR * 3.0 + trap + lie),
        0.88,
        1.18 + 0.24 * heart
    ));

    vec3 scriptCol = hsv2rgb(vec3(
        0.10 + 0.04 * sin(r * 19.0 - t + phase),
        0.90,
        1.30 + lie * 0.32
    ));

    vec3 irisCol = vec3(0.15, 0.70, 1.65) * (1.0 + 0.35 * heart);

    vec3 col = vec3(0.0);
    col += membraneCol * membrane * 1.15 * MEMBRANE_GAIN;
    col += veinCol * veins * 0.58 * NERVE_GAIN;
    col += scriptCol * script * 0.92;
    col += irisCol * iris * 0.32;

    return col * transfer;
}

vec3 quasiCrystal(vec2 p, float t)
{
    float r = length(p);
    float transfer = transferMask(r);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;

    vec3 col = vec3(0.0);
    float amp = 0.0;

    vec2 z;
    float trap;
    float phase;

    complexOrbit(p * 0.42, t, z, trap, phase);

    for (int i = 0; i < 7; ++i)
    {
        float fi = float(i);
        float a = fi * TAU / 7.0 + 0.08 * sin(t * 0.23 + fi + phase * 0.03);

        vec2 d = vec2(cos(a), sin(a));
        float wave = cos(
            dot(p + z * 0.03, d) * (10.0 + fi * 2.3 + chaos * 0.4) +
            t * (0.45 + fi * 0.04) +
            breath * 0.7
        );

        float ridge = smoothstep(0.965 - heart * 0.018, 1.0, wave);
        vec3 h = hsv2rgb(vec3(0.58 + fi * 0.037 + t * 0.008 + trap * 0.02, 0.68, 1.0 + heart * 0.08));

        col += h * ridge;
        amp += ridge;
    }

    return transfer * col / (1.0 + amp * 0.35);
}

vec3 spectralLens(vec2 uv, vec2 p, float t)
{
    float r = length(p);
    float a = atan(p.y, p.x);
    float transfer = transferMask(r);
    vec2 dir = normalize(p + 1e-6);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    vec2 z;
    float trap;
    float phase;

    complexOrbit(p * 0.62, t, z, trap, phase);

    float rip = rippleField(p, t, phase);

    float n0 = fbm2(uv * 3.0 + vec2(t * 0.045, -t * 0.032) + z * 0.025 * transfer);
    float n1 = fbm2(vec2(uv.x * 7.0, uv.y * 38.0 - t * 1.85) + z.yx * 0.018 * transfer);

    vec2 local = rippleDisplace(p, t, phase);

    vec2 warped = local;
    warped *= rot(
        0.07 * sin(t * 0.4 + breath * 0.2) +
        transfer * 0.055 / (0.16 + r * r) * sin(a * 3.0 + t + phase * 0.04)
    );

    warped += transfer * 0.032 * vec2(
        sin(warped.y * 8.0 + t * 1.3 + n0 * 5.0 + z.x + chaos),
        cos(warped.x * 9.0 - t * 1.1 + n1 * 5.0 + z.y - chaos)
    );

    warped += transfer * lie * LIE_AMOUNT * 0.024 * vec2(
        sin(t * 5.3 + phase * 0.17),
        cos(t * 4.7 - phase * 0.13)
    );

    local = safeTransfer(p, warped);

    vec2 suv = local * 0.5 + 0.5;
    suv = mix(uv, suv, 0.42 * transfer + 0.18);
    suv += dir * transfer * (0.014 * sin(r * 19.0 - t * 1.4 + n0 * 4.0) + rip * 0.006);
    suv += transfer * vec2(n1 - 0.5, n0 - 0.5) * 0.012;

    float ca = 0.003 + 0.012 * smoothstep(0.05, 1.35, r);
    ca += 0.006 * sat(1.0 - trap);
    ca *= transfer * (1.0 + 0.25 * heart + 0.20 * lie);

    return sourceCA(suv, dir, ca);
}

vec3 edgeField(vec2 uv, vec2 px)
{
    vec3 c = texture(iChannel0, uv).rgb;

    float l0 = dot(c, vec3(0.299, 0.587, 0.114));
    float lx = dot(texture(iChannel0, uv + vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float ly = dot(texture(iChannel0, uv + vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));

    float e = length(vec2(lx - l0, ly - l0));

    return vec3(e * e * 8.0);
}

vec2 clothFold(vec2 p, float t, vec4 attention, vec4 bio, float phase)
{
    float r = length(p);
    float a = atan(p.y, p.x);

    float gaze = attention.x;
    float prey = attention.y;
    float memory = attention.z;
    float flare = attention.w;

    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    float transfer = transferMask(r);

    float radialPleat = sin(
        a * (8.0 + 4.0 * memory) +
        r * (18.0 + 9.0 * flare) -
        t * (0.9 + 1.3 * heart) +
        phase * 0.04
    );

    float clothWave = sin(
        p.x * 9.0 +
        sin(p.y * 7.0 + t * 0.7) * 2.2 +
        t * (0.45 + 1.4 * flare)
    );

    float aperture = smoothstep(0.42, 1.0, memory + flare * 0.7);
    float close = 1.0 - aperture;

    vec2 radial = normalize(p + 1e-6);
    vec2 tangent = vec2(-radial.y, radial.x);

    vec2 folded = p;
    folded += radial * radialPleat * transfer * CLOTH_REALISM * 0.028 * (0.35 + flare);
    folded += tangent * clothWave * transfer * CLOTH_REALISM * 0.020 * (0.45 + memory);
    folded *= 1.0 + transfer * (0.065 * flare - 0.035 * close + 0.016 * breath);

    folded *= rot(
        transfer *
        (
            0.018 * sin(t * 0.31 + phase * 0.013) +
            0.090 * flare * FLARE_AMOUNT +
            0.038 * lie * LIE_AMOUNT
        )
    );

    vec2 recoil = -radial * transfer * gaze * WATCHFULNESS * 0.025;
    vec2 lunge = radial * transfer * prey * flare * PREY_RESPONSE * 0.038;

    return safeTransfer(p, folded + recoil + lunge);
}

vec3 apertureMouth(vec2 p, float t, vec4 attention, vec4 bio, float phase)
{
    float r = length(p);
    float a = atan(p.y, p.x);
    float transfer = transferMask(r);

    float gaze = attention.x;
    float prey = attention.y;
    float memory = attention.z;
    float flare = attention.w;

    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    float aperture = smoothstep(0.32, 0.94, memory + flare * 0.85 + prey * 0.28);
    float rimRadius = 0.34 + 0.12 * aperture + 0.025 * sin(t * 0.73 + phase * 0.05);
    float rim = smoothstep(0.040, 0.000, abs(r - rimRadius));

    float pleat = sin(
        a * (12.0 + 8.0 * aperture) +
        t * (1.1 + heart * 2.6) +
        phase * 0.06
    );

    float inner = smoothstep(rimRadius, rimRadius - 0.22 - 0.10 * aperture, r);
    float teeth = smoothstep(0.78, 1.0, pleat * 0.5 + 0.5) * rim;
    float iris = sin(r * 76.0 - a * 5.0 + t * 2.0 + phase * 0.12);
    iris = smoothstep(0.55, 1.0, iris) * inner;

    vec3 dusk = vec3(0.035, 0.032, 0.055);
    vec3 rimCol = hsv2rgb(vec3(0.58 + 0.08 * chaos + 0.03 * lie, 0.42, 1.18 + heart * 0.3));
    vec3 nerveCol = hsv2rgb(vec3(0.08 + 0.05 * sin(t + phase), 0.88, 1.55));

    vec3 col = vec3(0.0);
    col += dusk * inner * (0.8 + aperture);
    col += rimCol * rim * (0.65 + aperture * 0.95);
    col += nerveCol * teeth * (0.30 + flare);
    col += vec3(0.08, 0.42, 1.25) * iris * 0.25;

    return col * transfer * aperture;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float t = iTime * LIFE_RATE;
    float r = length(p);
    float transfer = transferMask(r);
    float core = coreMask(r);

    vec4 bio = livingState(t, r);
    float breath = bio.x;
    float heart = bio.y;
    float chaos = bio.z;
    float lie = bio.w;

    vec4 attention = attentionState(uv, p, px, t);
    float gaze = attention.x;
    float prey = attention.y;
    float memory = attention.z;
    float flare = attention.w;

    vec2 dir = normalize(p + 1e-6);

    vec2 z;
    float trap;
    float phase;

    complexOrbit(p * 0.74, t, z, trap, phase);

    float ripple = rippleField(p, t, phase);

    float livingExpansion = 1.0 + transfer * (
        BREATH_AMOUNT * 0.035 * (breath - 0.5) -
        HEART_AMOUNT * 0.018 * heart +
        CHAOS_AMOUNT * 0.014 * (chaos - 0.5) +
        FLARE_AMOUNT * 0.035 * flare -
        WATCHFULNESS * 0.020 * gaze
    );

    vec2 livingP = p * livingExpansion;
    livingP = clothFold(livingP, t, attention, bio, phase);

    float drift = fbm2(uv * 3.2 + vec2(t * 0.052, -t * 0.034) + z * 0.018 * transfer);
    float heat  = fbm2(vec2(uv.x * 8.0, uv.y * 44.0 - t * 2.1) + z.yx * 0.014 * transfer);

    vec2 shimmer = vec2(
        sin(uv.y * 23.0 + t * 1.63 + phase * 0.03 * transfer),
        cos(uv.x * 19.0 - t * 1.17 + length(z) * 0.2 * transfer)
    );

    shimmer *= transfer * (0.002 + 0.004 * drift) * (1.0 + 0.35 * heart + 0.50 * flare);
    shimmer.x += transfer * (heat - 0.5) * 0.007 * smoothstep(0.12, 1.10, r);
    shimmer += dir * ripple * (0.010 + 0.010 * flare);

    shimmer += transfer * TWITCH_AMOUNT * heart * 0.004 * vec2(
        sin(t * 8.7 + chaos * 11.0 + gaze * 3.0),
        cos(t * 7.9 - chaos * 9.0 + prey * 2.0)
    );

    shimmer += transfer * gaze * WATCHFULNESS * 0.005 * vec2(
        sin(t * 5.1 + phase * 0.07),
        cos(t * 4.6 - phase * 0.05)
    );

    vec2 luvWarped = barrel(uv + shimmer, 0.065 + 0.015 * sat(1.0 - trap) * transfer + 0.025 * flare);
    vec2 luv = mix(uv, luvWarped, transfer);

    float fieldA = fbm3(vec3(livingP * 1.25 + z * 0.03 * transfer, t * 0.075 + breath * 0.05 + memory * 0.10));
    float fieldB = fbm3(vec3(livingP.yx * 3.05 + fieldA + z.yx * 0.025 * transfer, -t * 0.105 + chaos * 0.08 + flare * 0.12));

    vec2 q = rippleDisplace(livingP, t, phase);

    vec2 qWarped = q;

    qWarped += transfer * 0.062 * vec2(
        sin(qWarped.y * 6.0 + t * 1.25 + fieldA * 7.0 + z.x + heart + gaze),
        cos(qWarped.x * 7.0 - t * 1.10 + fieldB * 7.0 + z.y - heart + prey)
    );

    qWarped *= rot(transfer * (
        0.055 * sin(t * 0.37) +
        0.13 * fieldB +
        phase * 0.008 +
        lie * LIE_AMOUNT * 0.075 +
        flare * FLARE_AMOUNT * 0.16 -
        gaze * WATCHFULNESS * 0.045
    ));

    qWarped /= 1.0 + transfer * (0.13 + flare * 0.08) * sin(r * 8.0 - t * 0.9 + fieldA * 3.0 + ripple);

    vec2 lieOffset = vec2(
        sin(t * 3.7 + phase * 0.11 + chaos * 5.0),
        cos(t * 3.1 - phase * 0.09 - chaos * 4.0)
    );

    qWarped += transfer * lie * LIE_AMOUNT * lieOffset * 0.035;
    qWarped += transfer * flare * FLARE_AMOUNT * normalize(qWarped + 1e-6) * 0.055;
    qWarped -= transfer * gaze * WATCHFULNESS * normalize(qWarped + 1e-6) * 0.026;

    q = safeTransfer(p, qWarped);

    vec3 rawSource = sourceCA(luv, dir, transfer * (0.0025 + 0.006 * smoothstep(0.15, 1.35, r)));
    vec3 cleanCore = texture(iChannel0, uv).rgb;

    vec3 lens      = spectralLens(luv, q, t);
    vec3 manifold  = manifoldLayer(q, t);
    vec3 complex   = complexLayer(q * 0.92, t);
    vec3 crystal   = quasiCrystal(q * (1.0 + 0.4 * sin(t * 0.09 + phase * 0.03)), t);
    vec3 bloom     = sourceBloom(luv, px);
    vec3 edge      = edgeField(luv, px);
    vec3 mouth     = apertureMouth(q, t, attention, bio, phase);

    float portal = smoothstep(1.22, 0.07, r);

    float mask = smoothstep(
        0.10,
        0.90,
        fbm3(vec3(q * 2.1 + z * 0.03 * transfer, t * 0.18 + chaos * 0.1 + memory * 0.12))
    );

    float ringRadius = 0.62 +
        0.035 * sin(t * 0.9 + fieldA * 7.0 + ripple * 2.0) +
        0.018 * BREATH_AMOUNT * (breath - 0.5) -
        0.011 * HEART_AMOUNT * heart +
        0.040 * flare -
        0.020 * gaze;

    float ring = smoothstep(0.020 + flare * 0.018, 0.000, abs(r - ringRadius));

    float rippleHighlight = smoothstep(0.72, 1.0, ripple * 0.5 + 0.5);
    rippleHighlight *= smoothstep(1.18, 0.06, r);
    rippleHighlight *= transfer;

    vec3 col = rawSource;

    float reveal = sat(0.38 + 0.45 * mask + 0.44 * memory + 0.55 * flare - 0.18 * gaze);
    float foldExposure = sat(0.33 + 0.52 * flare + 0.25 * prey + 0.18 * heart);

    col = mix(col, lens, 0.52 * transfer + 0.18 * flare);
    col = mix(col, manifold, transfer * reveal);
    col = mix(col, complex, transfer * (0.16 + 0.22 * sat(1.0 - trap) + 0.18 * gaze));

    col += crystal * 0.21 * portal * (1.0 + flare);
    col += complex * 0.36 * portal * (1.0 + memory * 0.7);
    col += bloom * 0.20 * transfer * (1.0 + 0.35 * heart + 0.65 * flare);
    col += edge * vec3(0.45, 0.80, 1.45) * 0.16 * transfer * (1.0 + gaze * 0.6);

    col += manifold * ring * (1.30 + 0.50 * heart + 1.15 * flare);
    col += mouth * (0.55 + 1.55 * foldExposure);

    col += hsv2rgb(vec3(0.55 + phase * 0.015 + chaos * 0.03, 0.72, 1.0)) * rippleHighlight * (0.16 + 0.20 * flare);

    vec3 lieColor = hsv2rgb(vec3(
        0.72 + 0.11 * sin(phase * 0.05 + t),
        0.90,
        1.18
    ));

    col = mix(col, col.brg * (0.82 + lieColor * 0.45), transfer * lie * LIE_AMOUNT * (0.18 + 0.20 * memory));

    float shadowFold = smoothstep(0.22, 0.88, memory) * smoothstep(0.95, 0.15, r);
    col *= 1.0 - shadowFold * gaze * WATCHFULNESS * 0.18;

    col *= 0.58 + 0.72 * portal + 0.18 * flare;

    float blackCoreRadius = 0.215 +
        0.026 * sin(t * 0.74 + phase * 0.05 + breath * 0.4) +
        0.065 * flare -
        0.024 * gaze;

    float blackCore = smoothstep(0.100 + flare * 0.05, 0.000, abs(r - blackCoreRadius));
    blackCore *= transfer;

    col = mix(col, vec3(0.0), blackCore * (0.38 + 0.18 * lie + 0.30 * gaze));
    col += blackCore * vec3(2.4, 1.05, 0.30) * (0.18 + 0.12 * heart + 0.42 * flare);

    float scan = sin(fragCoord.y * 1.17 + t * 11.0 + ripple * 2.0);
    float scanFine = sin(fragCoord.y * 3.0 + phase * 0.04 * transfer);
    float grille = sin(fragCoord.x * 0.33 + sin(fragCoord.y * 0.021 + t + phase * 0.01 * transfer) * 3.0);

    col *= 0.958 + 0.024 * scan + 0.009 * scanFine + 0.014 * grille;

    float grain = hash12(fragCoord + fract(t) * 911.17 + z * 3.0 * transfer);
    float grainSoft = fbm2(fragCoord * 0.36 + t * 13.0 + z.yx * 2.0 * transfer);

    col += (grain - 0.5) * 0.038 * (1.0 + 0.3 * chaos + 0.6 * memory);
    col += (grainSoft - 0.5) * 0.014;

    vec3 spectralNoise = vec3(
        sin(t * 2.0 + uv.y * 91.0 + fieldA * 9.0 + phase * 0.09 * transfer),
        sin(t * 2.3 + uv.y * 83.0 + fieldB * 7.0 + 2.0 + trap * transfer),
        sin(t * 1.7 + uv.y * 77.0 + fieldA * 5.0 + 4.0 + length(z) * transfer)
    );

    col += spectralNoise * 0.021 * transfer * (1.0 + 0.45 * heart + 0.85 * flare);

    float pulse = 0.5 + 0.5 * sin(t * 0.69 + phase * 0.02 * transfer);
    pulse = mix(pulse, max(pulse, heart), 0.45 * HEART_AMOUNT);
    pulse = mix(pulse, max(pulse, flare), 0.35 * FLARE_AMOUNT);

    col *= 0.985 + 0.035 * pulse * smoothstep(0.9, 0.0, r);

    float vignette = smoothstep(1.48, 0.10, r);
    vignette *= 0.84 + 0.16 * smoothstep(0.95, 0.0, abs(p.x * 0.52) + abs(p.y));
    col *= vignette;

    col += pow(max(0.0, 1.0 - r), 6.0) * vec3(0.07, 0.018, 0.14) * (1.0 + 0.25 * breath + 0.65 * flare);

    cleanCore *= 0.96 + 0.04 * sin(t * 0.69);
    cleanCore *= 1.0 + 0.025 * heart;
    cleanCore *= 1.0 - 0.045 * gaze;
    cleanCore *= smoothstep(1.48, 0.10, r);

    col = mix(cleanCore, col, transfer);

    vec3 watchTint = hsv2rgb(vec3(0.57 + 0.04 * chaos, 0.35 + 0.35 * gaze, 1.0));
    col = mix(col, col * watchTint, transfer * gaze * 0.16);

    col = tonemap(col * (1.10 + 0.07 * heart + 0.04 * lie + 0.16 * flare));
    col = pow(col, vec3(0.88 - 0.035 * ORGANIC_COLOR * heart + 0.018 * gaze));

    fragColor = vec4(col, 1.0);
}