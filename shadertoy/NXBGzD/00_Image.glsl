// SPDX-License-Identifier: CC-BY-NC-SA-4.0
// Incorporates/adapts Holofoil Dice by @Jaenam, CC BY-NC-SA 4.0
// Original credit retained per source license.

#define PI  3.14159265359
#define TAU 6.28318530718

#define MAX_STEPS 120
#define MAX_DIST  9.0
#define SURF_DIST 0.0007

float opSmoothUnion(float d1, float d2, float k)
{
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float sdSphere(vec3 p, float s)
{
    return length(p) - s;
}

mat2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

float hash13(vec3 p)
{
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(TAU * (vec3(0.00, 0.14, 0.36) + t));
}

vec2 flow2(vec2 p, float t)
{
    vec2 v = vec2(0.0);

    v += 0.75 * vec2(
        cos(1.4 * p.y + 1.1 * t),
        sin(1.7 * p.x - 0.8 * t)
    );

    v += 0.45 * vec2(
        sin(2.8 * p.y - 0.6 * t),
        cos(2.4 * p.x + 0.9 * t)
    );

    v += 0.25 * vec2(
        cos(4.3 * (p.x + p.y) + 0.4 * t),
        sin(3.6 * (p.x - p.y) - 0.5 * t)
    );

    return v;
}

vec2 kalei(vec2 p, float sectors)
{
    float a = atan(p.y, p.x);
    float r = length(p);
    float n = TAU / sectors;

    a = mod(a, n);
    a = abs(a - 0.5 * n);

    return vec2(cos(a), sin(a)) * r;
}

float quasicrystal(vec2 uv, float t, out float chroma)
{
    float total = 0.0;
    chroma = 0.0;

    for (int j = 0; j < 11; j++)
    {
        float i = float(j);

        float angle = PI * i / (7.0 + 2.5 * cos(2.0 * i) + 1.5 * sin(3.0 * i));
        vec2 dir = vec2(cos(angle), sin(angle));

        float len = dot(uv, dir);
        float phase = 26.0 * len + t + 1.2 * sin(len * 3.0 + i * 1.618);

        float w = cos(phase);

        total += 0.5 + 0.5 * w;
        chroma += sin(phase + i * 1.111);
    }

    return 1.0 - abs(2.0 * fract(0.5 * total) - 1.0);
}

float fractalPsy(vec2 p, float t, out float glow)
{
    float acc = 0.0;
    float wsum = 0.0;
    float g = 0.0;

    vec2 z = p;

    for (int i = 0; i < 7; i++)
    {
        float fi = float(i);

        z = kalei(z, 5.0 + fi);
        z = abs(z);
        z = rot(0.28 * sin(t * 0.45 + fi) + 0.72) * z;
        z = z * 1.62 - vec2(0.44, 0.17);
        z += 0.20 * flow2(z + p * 0.23, t * (1.0 + 0.075 * fi));

        float c;
        float q = quasicrystal(z * (1.0 + 0.20 * fi), t * (1.0 + 0.13 * fi), c);
        float band = 0.5 + 0.5 * sin(9.0 * q + 1.9 * c + t + fi);

        float w = 1.0 / (1.0 + fi * 0.75);

        acc += band * w;
        wsum += w;
        g += exp(-3.3 * abs(q - 0.5)) * w;
    }

    glow = g / wsum;
    return acc / wsum;
}

vec3 domainWarp(vec3 p)
{
    vec3 q = p;

    q.xy *= rot(0.38 * sin(iTime * 0.45 + p.z * 1.1));
    q.xz *= rot(0.27 * cos(iTime * 0.30 + p.y * 1.3));
    q.yz *= rot(0.22 * sin(iTime * 0.35 + p.x * 0.9));

    q += 0.17 * sin(vec3(
        2.3 * p.y + 1.1 * iTime,
        2.0 * p.z - 0.9 * iTime,
        2.6 * p.x + 0.7 * iTime
    ));

    return q;
}

float holoDiceChannel(vec3 p, float zoff)
{
    vec3 q = p;

    q.xz *= rot(0.25 * iTime + 0.25 * sin(q.y));
    q.yz *= rot(0.19 * iTime + 0.20 * cos(q.x));
    q.xy *= rot(0.13 * iTime);

    vec3 cell = floor(q * 6.0);
    vec3 f = fract(q * 6.0) - 0.5;

    float rnd = hash13(cell);
    float h = step(length(f), rnd * 0.30 + 0.10);
    float a = hash13(cell + vec3(43.7, 78.2, 123.4)) * TAU;

    float e = 1.0;
    float sc = 2.0;

    for (int j = 0; j < 4; j++)
    {
        vec3 g = abs(mod(q * sc, 2.0) - 1.0);

        float edge = min(
            max(g.x, g.y),
            min(max(g.y, g.z), max(g.x, g.z))
        ) / sc;

        e = min(e, edge);
        sc *= 0.62;
    }

    float cube = max(
        max(max(abs(q.x), abs(q.y)), abs(q.z)),
        dot(abs(q), vec3(0.577)) * 0.9
    ) - 3.0;

    float folded = abs(sin(cube * 3.0 + dot(q, vec3(1.7, 2.3, 1.1)))) - 0.30;
    float d = max(max(cube, e - 0.10), folded);

    float s = 0.01 + 0.15 * abs(d + zoff * 0.02);
    float sf = smoothstep(0.025, 0.006, s);

    float shimmer = 0.5 + 0.5 * sin(
        a
        + iTime * 4.5
        + zoff * 5.0
        + dot(cell, vec3(0.31, 0.47, 0.63))
    );

    float v = 1.6 / s;
    v *= 0.45 + 0.55 * sin(0.3 * length(cell) + zoff * 5.0 + iTime);
    v += sf * 7.0 * h * shimmer;

    return max(v, 0.0);
}

vec3 holoDice(vec3 p)
{
    vec3 h = vec3(
        holoDiceChannel(p, -1.0),
        holoDiceChannel(p,  0.0),
        holoDiceChannel(p,  1.0)
    );

    return 1.0 - exp(-h * h / 9500.0);
}

float map(vec3 p)
{
    vec3 q = domainWarp(p);

    float d = 10.0;
    const float golden = 2.39996323;

    for (int i = 0; i < 18; i++)
    {
        float fi = float(i);
        float seed = fract(fi * 412.531 + 0.5124);

        float a = fi * golden + 0.42 * iTime * (0.25 + seed);
        float r = mix(0.20, 1.55, fract(fi * 0.75487766));

        vec3 c = vec3(
            cos(a) * r + 0.45 * sin(iTime * (0.8 + seed * 1.5) + fi * 2.1),
            1.25 * sin(iTime * (0.55 + seed * 0.9) + fi * 1.7) + 0.35 * cos(fi * 1.13),
            sin(a) * (0.55 + 0.35 * r) + 0.28 * cos(iTime * (0.9 + seed) + fi * 1.9)
        );

        float rad = mix(0.33, 0.92, seed);
        float s = sdSphere(q - c, rad);

        d = opSmoothUnion(s, d, 0.60);
    }

    float glowDummy;
    float surfPat = fractalPsy(q.xy * 1.8 + q.z * 0.55, iTime * 0.7, glowDummy);

    vec3 holo = holoDice(q * 0.72);
    float holoBump = dot(holo, vec3(0.333));

    d += 0.050 * (surfPat - 0.5);
    d += 0.030 * (holoBump - 0.5);

    return d;
}

vec3 calcNormal(vec3 p)
{
    const float h = 0.0008;
    const vec2 k = vec2(1.0, -1.0);

    return normalize(
          k.xyy * map(p + k.xyy * h)
        + k.yyx * map(p + k.yyx * h)
        + k.yxy * map(p + k.yxy * h)
        + k.xxx * map(p + k.xxx * h)
    );
}

float raymarch(vec3 ro, vec3 rd, out vec3 p, out float marchGlow)
{
    float t = 0.0;
    marchGlow = 0.0;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        p = ro + rd * t;

        float d = map(p);

        vec3 holo = holoDice(p * 0.48 + vec3(0.0, 0.0, iTime * 0.08));
        marchGlow += 0.012 * dot(holo, vec3(0.333)) / (0.08 + d * d);

        if (d < SURF_DIST) break;

        t += d * 0.80;

        if (t > MAX_DIST) break;
    }

    return t;
}

vec3 shade(vec3 p, vec3 rd, float marchGlow)
{
    vec3 n = calcNormal(p);

    vec3 up = abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tx = normalize(cross(up, n));
    vec3 ty = cross(n, tx);

    vec2 suv = vec2(dot(p, tx), dot(p, ty));
    vec2 flow = flow2(suv * 1.2 + 0.35 * p.xz, iTime);

    suv += 0.32 * flow;
    suv = kalei(suv, 7.0 + 2.0 * sin(iTime * 0.3));
    suv += 0.12 * vec2(
        sin(iTime + 4.0 * p.y),
        cos(0.8 * iTime + 3.0 * p.x)
    );

    float qcChroma;
    float qc = quasicrystal(
        suv * 1.55,
        2.0 * iTime + 2.4 * dot(flow, vec2(0.7, 0.4)),
        qcChroma
    );

    float psyGlow;
    float psy = fractalPsy(suv * 1.75 + 0.2 * p.xy, 1.6 * iTime, psyGlow);

    vec3 holo = holoDice(p * 0.92 + 0.20 * vec3(flow, sin(iTime)));

    vec3 lightDir = normalize(vec3(-0.45, 0.72, 0.52));
    float diff = max(dot(n, lightDir), 0.0);
    float rim  = pow(1.0 - max(dot(n, -rd), 0.0), 2.0);
    float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 36.0);

    float phase = 0.20 * qcChroma + 0.65 * psy + 0.08 * iTime;

    vec3 neonA = palette(phase);
    vec3 neonB = palette(phase + 0.23);
    vec3 neonC = palette(phase + 0.47);

    vec3 lava = mix(
        vec3(0.13, 0.015, 0.005),
        vec3(1.55, 0.34, 0.015),
        qc
    );

    vec3 fractCol = mix(neonA, neonB, psy);
    fractCol = mix(fractCol, neonC, 0.35 + 0.35 * sin(qcChroma));

    vec3 holoCol = mix(holo, palette(phase + dot(holo, vec3(0.4, 0.2, 0.7))), 0.45);

    vec3 col = mix(lava, fractCol, 0.55 + 0.35 * psyGlow);
    col = mix(col, holoCol * 1.65, 0.28 + 0.42 * dot(holo, vec3(0.333)));

    col *= 0.26 + 0.98 * diff;

    col += 0.58 * psyGlow * fractCol;
    col += 0.55 * holo * (0.35 + 0.65 * rim);
    col += 0.30 * rim * mix(vec3(1.0, 0.25, 0.07), neonB, 0.75);
    col += 0.45 * spec * vec3(1.0, 0.92, 0.76);
    col += 0.10 * marchGlow * mix(neonA, holoCol, 0.65);

    col = pow(max(col, 0.0), vec3(0.80));

    return col;
}

vec3 background(vec2 uv)
{
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    vec2 k = kalei(uv * 1.6, 9.0 + 2.0 * sin(iTime * 0.2));

    float c;
    float q = quasicrystal(k * 2.0, iTime * 1.4 + a * 2.0, c);

    vec3 bg = mix(
        vec3(0.006, 0.000, 0.025),
        vec3(0.08, 0.015, 0.006),
        exp(-3.5 * r * r)
    );

    bg += 0.08 * palette(0.14 * c + 0.2 * q + 0.03 * iTime) * q * exp(-2.0 * r);

    return bg;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(uv * 6.0, 3.25);
    vec3 rd = vec3(0.0, 0.0, -1.0);

    vec3 p;
    float marchGlow;
    float depth = raymarch(ro, rd, p, marchGlow);

    vec3 col = background(uv);

    if (depth < MAX_DIST)
    {
        col = shade(p, rd, marchGlow);
        col *= exp(-0.085 * depth);
    }

    float vignette = smoothstep(1.45, 0.15, length(uv));
    col *= 0.75 + 0.35 * vignette;

    col = col / (1.0 + col * 0.55);

    float alpha = 1.0 - clamp((depth - 0.35) / 2.4, 0.0, 1.0);

    fragColor = vec4(col, alpha);
}