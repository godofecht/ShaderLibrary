#define MAIN_STEPS 56
#define LIGHT_STEPS 4
#define FAR_T 13.5

float hash31(vec3 p)
{
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float noise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, u.x);
    float x10 = mix(n010, n110, u.x);
    float x01 = mix(n001, n101, u.x);
    float x11 = mix(n011, n111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float fbm3(vec3 p)
{
    float v = 0.0;
    float a = 0.5;

    v += a * noise3(p); p.xy = rot(0.37) * p.xy * 2.03 + 11.7; p.xz = rot(0.24) * p.xz * 2.01; a *= 0.5;
    v += a * noise3(p); p.xy = rot(0.37) * p.xy * 2.03 + 17.3; p.xz = rot(0.24) * p.xz * 2.01; a *= 0.5;
    v += a * noise3(p); p.xy = rot(0.37) * p.xy * 2.03 + 23.1; p.xz = rot(0.24) * p.xz * 2.01; a *= 0.5;
    v += a * noise3(p);

    return v;
}

float ridged3(vec3 p)
{
    float v = 0.0;
    float a = 0.5;

    v += a * abs(noise3(p) * 2.0 - 1.0); p.xy = rot(0.31) * p.xy * 2.04 + 7.1; p.xz = rot(0.21) * p.xz * 2.02; a *= 0.55;
    v += a * abs(noise3(p) * 2.0 - 1.0); p.xy = rot(0.31) * p.xy * 2.04 + 13.4; p.xz = rot(0.21) * p.xz * 2.02; a *= 0.55;
    v += a * abs(noise3(p) * 2.0 - 1.0);

    return v;
}

vec3 flow(vec3 p)
{
    float t = iTime;

    p.x += t * 0.42;
    p.z -= t * 0.08;

    float yShear = p.y * 0.16;
    p.x += yShear * t * 0.025;

    p.x += sin(p.z * 0.22 + t * 0.12) * 0.14;
    p.z += cos(p.x * 0.18 + t * 0.10) * 0.10;

    return p;
}

float densityCheap(vec3 p)
{
    p = flow(p);

    vec3 q = p;

    float w = fbm3(q * vec3(0.32, 0.22, 0.32) + vec3(iTime * 0.025, 2.1, -iTime * 0.012));
    q.xz += (w - 0.5) * 1.15;

    float large = fbm3(q * vec3(0.36, 0.22, 0.36));
    float mid = noise3(q * vec3(1.25, 0.75, 1.25) + vec3(17.0, iTime * 0.04, 3.0));
    float crisp = ridged3(q * vec3(2.8, 1.9, 2.8) + vec3(9.0, 0.0, -iTime * 0.08));

    float d = large * 0.76 + mid * 0.22 + crisp * 0.08;

    float height = smoothstep(-0.35, 0.12, p.y) * smoothstep(1.32, 0.25, p.y);
    d += height * 0.18;

    d = smoothstep(0.48, 0.83, d);
    d *= height;

    return clamp(d, 0.0, 1.0);
}

float densityLight(vec3 p)
{
    p = flow(p);

    float d = fbm3(p * vec3(0.34, 0.22, 0.34));
    float h = smoothstep(-0.35, 0.12, p.y) * smoothstep(1.32, 0.25, p.y);

    d += h * 0.16;
    d = smoothstep(0.48, 0.82, d);
    d *= h;

    return clamp(d, 0.0, 1.0);
}

float lightMarch(vec3 p, vec3 sunDir)
{
    float trans = 1.0;
    float t = 0.18;

    for (int i = 0; i < LIGHT_STEPS; ++i)
    {
        float d = densityLight(p + sunDir * t);
        trans *= exp(-d * 1.35);
        t += 0.34;
    }

    return trans;
}

vec3 skyColor(vec3 rd)
{
    float h = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);

    vec3 horizon = vec3(0.78, 0.84, 0.90);
    vec3 zenith = vec3(0.25, 0.43, 0.70);

    vec3 col = mix(horizon, zenith, h * h);

    vec3 sunDir = normalize(vec3(0.85, 0.33, 0.40));
    float s = max(dot(rd, sunDir), 0.0);

    col += vec3(1.0, 0.86, 0.62) * pow(s, 32.0) * 0.30;
    col += vec3(1.0, 0.90, 0.75) * pow(s, 6.0) * 0.12;

    return col;
}

bool cloudBox(vec3 ro, vec3 rd, out float t0, out float t1)
{
    float a = (-0.35 - ro.y) / rd.y;
    float b = ( 1.35 - ro.y) / rd.y;

    t0 = min(a, b);
    t1 = max(a, b);

    t0 = max(t0, 0.0);
    t1 = min(t1, FAR_T);

    return t1 > t0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0.0, 0.18, -3.2);
    vec3 ta = vec3(0.0, 0.35, 0.0);

    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), ww));
    vec3 vv = cross(ww, uu);

    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.55 * ww);

    vec3 sunDir = normalize(vec3(0.85, 0.33, 0.40));
    vec3 sky = skyColor(rd);
    vec3 col = sky;

    float t0;
    float t1;

    if (abs(rd.y) > 0.0001 && cloudBox(ro, rd, t0, t1))
    {
        float T = 1.0;
        vec3 acc = vec3(0.0);

        float jitter = hash11(dot(fragCoord, vec2(12.9898, 78.233)));
        float t = t0 + jitter * 0.11;

        for (int i = 0; i < MAIN_STEPS; ++i)
        {
            if (t > t1 || T < 0.015) break;

            vec3 p = ro + rd * t;
            float d = densityCheap(p);

            float stepLen = mix(0.18, 0.055, d);
            stepLen *= 1.0 + t * 0.035;

            if (d > 0.012)
            {
                float lt = lightMarch(p, sunDir);

                float phaseF = pow(max(dot(rd, sunDir), 0.0), 7.0);
                float phaseB = pow(max(dot(rd, -sunDir), 0.0), 2.0);
                float phase = 0.25 + phaseF * 0.55 + phaseB * 0.08;

                vec3 shadowCol = vec3(0.58, 0.64, 0.71);
                vec3 midCol = vec3(0.78, 0.82, 0.86);
                vec3 sunCol = vec3(1.00, 0.96, 0.90);

                vec3 local = mix(shadowCol, midCol, lt);
                local = mix(local, sunCol, lt * lt * phase);

                local += sky * (0.12 + 0.18 * clamp(p.y, 0.0, 1.0));

                float a = 1.0 - exp(-d * stepLen * 1.85);

                acc += T * a * local;
                T *= 1.0 - a;
            }

            t += stepLen;
        }

        col = acc + sky * T;
    }

    float vignette = smoothstep(1.45, 0.28, length(uv * vec2(0.90, 0.76)));
    col *= mix(0.84, 1.03, vignette);

    col = pow(clamp(col, 0.0, 1.0), vec3(0.95));

    fragColor = vec4(col, 1.0);
}
