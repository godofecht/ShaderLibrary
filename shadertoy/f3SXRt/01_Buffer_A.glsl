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

float encodeParam(int id, float v)
{
    return saturate((v - paramMin(id)) / (paramMax(id) - paramMin(id)));
}

float defaultNorm(int id)
{
    return encodeParam(id, paramDefault(id));
}

float loadNorm(int id)
{
    if (iFrame == 0)
    {
        return defaultNorm(id);
    }

    return texelFetch(iChannel0, ivec2(id, 0), 0).x;
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

void mainImage(out vec4 O, in vec2 U)
{
    ivec2 P = ivec2(floor(U));

    if (P.y == 0 && P.x >= 0 && P.x < PARAM_COUNT)
    {
        int id = P.x;
        float n = loadNorm(id);

        if (iMouse.z > 0.0)
        {
            int hot = hoveredSlider(iMouse.xy);

            if (hot == id)
            {
                n = saturate((iMouse.x - TRACK_X0) / (TRACK_X1 - TRACK_X0));
            }
        }

        O = vec4(n, 0.0, 0.0, 1.0);
        return;
    }

    O = vec4(0.0);
}