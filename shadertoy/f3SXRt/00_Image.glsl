const int PARAM_COUNT = 10;

const float PANEL_X  = 20.0;
const float PANEL_Y  = 20.0;
const float ROW_H    = 24.0;
const float TRACK_X0 = 120.0;
const float TRACK_X1 = 300.0;

float saturate(float x)
{
    return clamp(x, 0.0, 1.0);
}

// Parameter order:
// 0 zoomSpeed
// 1 pulseAmp
// 2 pulseFreq
// 3 layerCount
// 4 fbmOctaves
// 5 densityGain
// 6 twist
// 7 glowStrength
// 8 sparkStrength
// 9 paletteDrift

float paramMin(int id)
{
    if (id == 0) return 0.00;
    if (id == 1) return 0.00;
    if (id == 2) return 0.00;
    if (id == 3) return 8.00;
    if (id == 4) return 1.00;
    if (id == 5) return 0.00;
    if (id == 6) return 0.00;
    if (id == 7) return 0.00;
    if (id == 8) return 0.00;
    return 0.00;
}

float paramMax(int id)
{
    if (id == 0) return 0.60;
    if (id == 1) return 0.50;
    if (id == 2) return 4.00;
    if (id == 3) return 96.00;
    if (id == 4) return 8.00;
    if (id == 5) return 2.00;
    if (id == 6) return 1.50;
    if (id == 7) return 0.50;
    if (id == 8) return 0.60;
    return 0.30;
}

float paramDefault(int id)
{
    if (id == 0) return 0.20;
    if (id == 1) return 0.12;
    if (id == 2) return 1.30;
    if (id == 3) return 56.00;
    if (id == 4) return 5.00;
    if (id == 5) return 1.00;
    if (id == 6) return 0.35;
    if (id == 7) return 0.12;
    if (id == 8) return 0.18;
    return 0.07;
}

float decodeParam(int id, float n)
{
    return mix(paramMin(id), paramMax(id), saturate(n));
}

float getParamNorm(int id)
{
    if (iFrame == 0)
    {
        return saturate((paramDefault(id) - paramMin(id)) / (paramMax(id) - paramMin(id)));
    }

    return texelFetch(iChannel0, ivec2(id, 0), 0).x;
}

float getParam(int id)
{
    return decodeParam(id, getParamNorm(id));
}

float hash3(vec3 p)
{
    return fract(sin(1e3 * dot(p, vec3(1.0, 57.0, -13.7))) * 4375.5453);
}

float noise3(vec3 x)
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(
            mix(hash3(p + vec3(0.0, 0.0, 0.0)), hash3(p + vec3(1.0, 0.0, 0.0)), f.x),
            mix(hash3(p + vec3(0.0, 1.0, 0.0)), hash3(p + vec3(1.0, 1.0, 0.0)), f.x),
            f.y
        ),
        mix(
            mix(hash3(p + vec3(0.0, 0.0, 1.0)), hash3(p + vec3(1.0, 0.0, 1.0)), f.x),
            mix(hash3(p + vec3(0.0, 1.0, 1.0)), hash3(p + vec3(1.0, 1.0, 1.0)), f.x),
            f.y
        ),
        f.z
    );
}

float noise(vec3 x)
{
    return 0.5 * (noise3(x) + noise3(x + 11.5));
}

float fbm(vec3 p, int octaves)
{
    float s = 0.0;
    float a = 0.5;

    for (int i = 0; i < 8; ++i)
    {
        if (i >= octaves)
        {
            break;
        }

        s += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }

    return s;
}

mat2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

vec3 palette(float t)
{
    return 0.55 + 0.45 * cos(6.28318 * (vec3(0.00, 0.12, 0.24) + t));
}

float rectAA(vec2 p, vec4 r, float aa)
{
    float x = smoothstep(r.x - aa, r.x + aa, p.x) * (1.0 - smoothstep(r.z - aa, r.z + aa, p.x));
    float y = smoothstep(r.y - aa, r.y + aa, p.y) * (1.0 - smoothstep(r.w - aa, r.w + aa, p.y));
    return x * y;
}

int hoveredSlider(vec2 m)
{
    if (m.x < TRACK_X0 || m.x > TRACK_X1)
    {
        return -1;
    }

    if (m.y < PANEL_Y || m.y >= PANEL_Y + ROW_H * float(PARAM_COUNT))
    {
        return -1;
    }

    int id = int(floor((m.y - PANEL_Y) / ROW_H));

    if (id < 0 || id >= PARAM_COUNT)
    {
        return -1;
    }

    return id;
}

vec3 drawUI(vec2 U, vec3 col)
{
    vec4 panel = vec4(
        PANEL_X - 14.0,
        PANEL_Y - 14.0,
        TRACK_X1 + 18.0,
        PANEL_Y + ROW_H * float(PARAM_COUNT) + 14.0
    );

    float panelMask = rectAA(U, panel, 1.5);
    col = mix(col, col * 0.35 + vec3(0.045, 0.05, 0.065), 0.88 * panelMask);

    int hot = hoveredSlider(iMouse.xy);

    for (int i = 0; i < PARAM_COUNT; ++i)
    {
        float y = PANEL_Y + ROW_H * (float(i) + 0.5);
        float n = getParamNorm(i);
        float x = mix(TRACK_X0, TRACK_X1, n);

        vec3 accent = palette(0.08 * float(i) + 0.11);

        float row = rectAA(U, vec4(PANEL_X, y - 10.0, TRACK_X1, y + 10.0), 1.0);
        float track = rectAA(U, vec4(TRACK_X0, y - 3.0, TRACK_X1, y + 3.0), 1.0);
        float fill = rectAA(U, vec4(TRACK_X0, y - 3.0, x, y + 3.0), 1.0);
        float knob = rectAA(U, vec4(x - 5.0, y - 8.0, x + 5.0, y + 8.0), 1.0);

        col += 0.02 * row;
        col = mix(col, col + vec3(0.06), 0.45 * track);
        col += 0.50 * accent * fill;
        col = mix(col, vec3(1.0), 0.75 * knob);

        if (i == hot)
        {
            col += 0.08 * accent * row;
        }
    }

    return col;
}

void mainImage(out vec4 O, vec2 U)
{
    float zoomSpeed    = getParam(0);
    float pulseAmp     = getParam(1);
    float pulseFreq    = getParam(2);
    float layerCount   = floor(getParam(3) + 0.5);
    int   fbmOctaves   = int(floor(getParam(4) + 0.5));
    float densityGain  = getParam(5);
    float twist        = getParam(6);
    float glowStrength = getParam(7);
    float sparkStrength= getParam(8);
    float paletteDrift = getParam(9);

    vec2 R = iResolution.xy;
    vec2 uv = (2.0 * U - R) / R.y;
    float t = iTime;

    vec2 p = uv;
    p *= rot(0.15 * sin(0.35 * t));

    float zoom = exp(zoomSpeed * t);
    float pulse = 1.0 + pulseAmp * sin(pulseFreq * t);

    vec3 col = vec3(0.0);
    float trans = 1.0;
    float glow = 0.0;

    vec3 bg = vec3(0.01, 0.005, 0.02);
    bg += 0.04 * palette(0.1 * length(uv) - paletteDrift * t);

    for (int i = 0; i < 96; ++i)
    {
        if (float(i) >= layerCount)
        {
            break;
        }

        float fi = float(i) / max(layerCount, 1.0);
        float depth = fi * fi;
        float z = 2.5 * fi + 1.25 * t;

        float scale = mix(0.6, 5.0, depth) * zoom * pulse;
        vec2 q = p * scale;

        q *= rot(twist * fi + 0.2 * sin(t + 9.0 * fi));
        q += 0.18 * vec2(sin(z + 2.0 * fi), cos(1.3 * z - fi));

        vec3 pp = vec3(q * 1.1, z);

        float f1 = fbm(pp, fbmOctaves);
        float f2 = fbm(pp * 1.9 + vec3(2.0, -1.0, 0.7), fbmOctaves);
        float f = mix(f1, f2, 0.35);

        float bands = sin(6.28318 * (8.0 * f - 1.6 * fi + 0.18 * t));
        float ribbon = pow(max(0.0, 1.0 - abs(bands)), 14.0);

        float cloud = smoothstep(0.42, 0.92, f);
        float shell = exp(-2.5 * abs(length(q) - (0.55 + 0.45 * sin(2.0 * f + 1.7 * fi))));
        float density = 0.95 * ribbon + 0.28 * cloud + 0.22 * shell;

        density *= mix(0.035, 0.11, 1.0 - fi) * densityGain;

        vec3 c = palette(f + 0.13 * fi - paletteDrift * t);
        c += 0.35 * palette(0.7 * f - 1.6 * paletteDrift * t + 0.4) * shell;
        c += 0.25 * vec3(1.0, 0.3, 0.8) * ribbon;

        col += c * density * trans;
        glow += density * (0.6 + 0.4 * cloud);

        trans *= 1.0 - clamp(density * 0.85, 0.0, 0.92);

        if (trans < 0.01)
        {
            break;
        }
    }

    col += bg * trans;
    col += glowStrength * glow * palette(0.12 * length(uv) - 2.0 * paletteDrift * t);

    float spark = hash3(vec3(floor(U * 0.5), floor(t * 14.0)));
    col += sparkStrength * smoothstep(0.995, 1.0, spark) * palette(length(uv) + 0.2 * t);

    float vignette = 1.0 - 0.16 * dot(uv, uv);
    col *= vignette;

    col = 1.0 - exp(-1.4 * col);
    col = pow(col, vec3(0.85));

    col = drawUI(U, col);

    O = vec4(col, 1.0);
}