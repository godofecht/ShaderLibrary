// Projection-mapped laser terrain
// smoother continuous scanlines, more stage-like, more contour/ridge focused

#define BPM 60.0
#define INTENSITY 1.0
#define HUE 0.90
#define HUE_RANGE 0.10

#define BEAT (iTime * BPM / 60.0)
#define TAU 6.28318530718
#define PI  3.14159265359
#define MAX_DIST 30.0

vec3 hsv2rgb(vec3 c)
{
    vec3 p = abs(fract(c.x + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 pal(float t)
{
    float h = HUE + (fract(t) - 0.5) * HUE_RANGE;
    float v = 0.55 + 0.45 * cos(TAU * t);
    return hsv2rgb(vec3(fract(h), 0.65, v));
}

float beatPulse()
{
    return exp(-fract(BEAT) * 5.0);
}

float hash21(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// periodic gaussian pulse train, continuous at loop boundary
float pulseTrain(float x, float width)
{
    float d = abs(fract(x) - 0.5);
    return exp(-(d * d) / max(width * width, 1e-5));
}

// antialiased contour line
float contourLine(float x, float freq, float width)
{
    float v = abs(sin(x * freq * PI));
    float fw = fwidth(x * freq) * 2.0 + 1e-4;
    return 1.0 - smoothstep(width, width + fw, v);
}

// terrain height
float hf(vec2 p)
{
    p *= 0.25;

    float a = 1.0;
    float h = 0.0;
    vec2 D = vec2(0.0);

    const mat2 R = mat2(6.0, 8.0, -8.0, 6.0) / 5.0;

    for (int i = 0; i < 8; ++i)
    {
        vec4 C = cos(p.xxyy + vec4(11.0, 0.0, 11.0, 0.0));
        vec3 w = C.yxx * C.zwz;

        D += w.xy;
        h += (a * w.z + a) / (3.0 * dot(D, D) + 1.0);

        a *= 0.5;
        p *= R;
        p += 1.23;
    }

    return h;
}

vec3 nf(vec2 p)
{
    const vec2 E = vec2(1e-3, 0.0);

    return normalize(vec3(
        hf(p - E.xy) - hf(p + E.xy),
        2.0 * E.x,
        hf(p - E.yx) - hf(p + E.yx)
    ));
}

float raymarch(vec3 ro, vec3 rd, float z0)
{
    float z = z0;

    for (int i = 0; i < 72; ++i)
    {
        vec3 p = ro + rd * z;
        float h = hf(p.xz);
        float d = p.y - h;

        if (d < 1e-3 || z > MAX_DIST) break;
        z += 0.8 * d;
    }

    return z;
}

vec3 aces_approx(vec3 v)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    v = max(v, 0.0);
    v *= 0.6;

    return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

vec3 terrainProjection(vec3 p, vec3 n, vec3 rd, vec3 ro)
{
    float h = hf(p.xz);

    // world axes for projection behavior
    float relz   = p.z - ro.z;           // depth ahead of camera
    float across = p.x;
    float along  = p.z;

    // terrain-following contours
    float c1 = contourLine(h,                    4.2, 0.060);
    float c2 = contourLine(h + 0.018 * across,  7.8, 0.040);
    float c3 = contourLine(h - 0.012 * along,   2.4, 0.085);

    float contour = max(c1, 0.75 * c2);
    contour = max(contour, 0.35 * c3);

    // projected scanlines sweeping from back to front
    // increasing BEAT shifts maxima toward smaller relz
    float scanA = pulseTrain(relz * 0.115 + BEAT * 0.88, 0.075);
    float scanB = pulseTrain(relz * 0.185 + BEAT * 1.24 + 0.18, 0.050) * 0.55;
    float scanC = pulseTrain(relz * 0.060 + BEAT * 0.42, 0.190) * 0.35;

    float scan = scanA + scanB + scanC;

    // projected side-to-side striping so it feels mapped rather than just height-lit
    float proj1 = contourLine(across + 0.55 * h, 0.90, 0.080);
    float proj2 = contourLine(across - 0.25 * h, 1.60, 0.050);
    float projectedStructure = max(0.55 * proj1, 0.35 * proj2);

    // ridge emphasis
    float ridge = pow(clamp(1.0 - n.y, 0.0, 1.0), 1.55);

    // soft continuous shimmer
    float shimmer = 0.5 + 0.5 * sin(1.8 * along - 3.6 * BEAT + 5.0 * h + 0.7 * across);

    // keep most energy on contours and scan fronts
    float lineEnergy   = contour * (0.10 + 1.10 * scanA + 0.55 * scanB + 0.10 * shimmer);
    float mapEnergy    = projectedStructure * contour * (0.05 + 0.60 * scanA);
    float ridgeEnergy  = ridge * (0.025 + 0.20 * scanC + 0.18 * scanA);

    float energy = lineEnergy + mapEnergy + ridgeEnergy;

    vec3 cool = pal(0.06 * h + 0.010 * along + 0.10 * BEAT);
    vec3 hot  = pal(0.31 + 0.020 * along + 0.16 * BEAT);

    vec3 col = mix(cool, hot, clamp(scanA * 0.9 + scanB * 0.5, 0.0, 1.0));
    col *= energy;

    // airy rim light
    float rim = pow(clamp(1.0 - max(dot(n, -rd), 0.0), 0.0, 1.0), 2.8);
    col += hot * rim * 0.11 * (0.35 + 0.65 * scanA);

    // slight distant bloom feel
    col += hot * contour * 0.02 * (scanA + 0.25 * scanB);

    return col;
}

void mainImage(out vec4 O, in vec2 fragCoord)
{
    vec2 R = iResolution.xy;
    vec2 uv = (fragCoord - 0.5 * R) / R.y;

    vec3 Z = normalize(vec3(0.0, -2.0, 7.0));
    vec3 X = normalize(cross(Z, vec3(0.0, 1.0, 0.0)));
    vec3 Y = cross(X, Z);

    vec3 ro = vec3(
        0.28 * sin(iTime * 0.17),
        4.0 + 0.10 * sin(iTime * 0.21),
        0.3 * iTime
    );

    vec3 rd = normalize(uv.y * Y - uv.x * X + Z);

    vec3 col = vec3(0.0);

    // dark stage void
    col += vec3(0.0018, 0.0026, 0.0068);

    // subtle volumetric atmosphere
    float vign = exp(-3.0 * dot(uv, uv));
    col += pal(0.07 * BEAT + 0.06 * uv.x) * vign * 0.010;

    // faint background scan haze
    float haze1 = pulseTrain((uv.y + 0.15) * 0.55 + BEAT * 0.33, 0.22);
    float haze2 = pulseTrain((uv.y - 0.20) * 0.85 + BEAT * 0.58, 0.12) * 0.4;
    col += pal(0.23 + 0.09 * BEAT) * (haze1 + haze2) * 0.008;

    float tz = (3.0 - ro.y) / rd.y;

    if (tz > 0.0 && tz < MAX_DIST)
    {
        float z = raymarch(ro, rd, tz);

        if (z < MAX_DIST)
        {
            vec3 p = ro + rd * z;
            vec3 n = nf(p.xz);

            vec3 holo = terrainProjection(p, n, rd, ro);

            float fog = exp(-0.0105 * z * z);
            float nearFade = smoothstep(MAX_DIST, 7.0, z);

            col += holo * fog * nearFade;

            // slight atmospheric lift around brighter regions
            col += holo * holo * 0.045 * fog;
        }
    }

    col *= 2.45 * INTENSITY;
    col = aces_approx(col);
    col = sqrt(max(col, 0.0)) - 0.04;

    O = vec4(col, 1.0);
}