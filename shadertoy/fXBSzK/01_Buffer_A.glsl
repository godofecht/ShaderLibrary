// ROCAILLE / VHS PLAID STAR TUNNEL — BUFFER A
// SETUP
// 1. Buffer A iChannel0 -> Buffer A
// 2. Filtering: Nearest
// 3. Wrap: Clamp

const int PARAM_COUNT = 9;

const float PANEL_X   = 18.0;
const float PANEL_TOP = 18.0;
const float HEADER_H  = 28.0;
const float ROW_H     = 24.0;
const float TRACK_X0  = 91.0;
const float TRACK_X1  = 252.0;

float getUIScale()
{
    float heightScale = iResolution.y / 600.0;
    float widthScale  = iResolution.x / 720.0;
    return clamp(min(heightScale, widthScale), 1.0, 2.10);
}

float defaultControl(int id)
{
    // 0 = SCAL, 1 = LENG, 2 = DETL, 3 = TURB, 4 = FREQ,
    // 5 = SPED, 6 = LAYR, 7 = HUE, 8 = GLOW
    // Keep scale at original default; max everything else.
    if (id == 0) return 0.333333;
    return 1.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 pixel = ivec2(floor(fragCoord));

    if (pixel.y != 0 || pixel.x < 0 || pixel.x >= PARAM_COUNT)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    int id = pixel.x;
    float value = iFrame == 0
        ? defaultControl(id)
        : texelFetch(iChannel0, ivec2(id, 0), 0).r;

    float uiScale = getUIScale();
    vec2 uiResolution = iResolution.xy / uiScale;

    if (iMouse.z > 0.0)
    {
        float pressX   = iMouse.z / uiScale;
        float pressY   = iMouse.w / uiScale;
        float currentX = iMouse.x / uiScale;

        float firstRowTop = uiResolution.y - PANEL_TOP - HEADER_H;
        int activeRow = int(floor((firstRowTop - pressY) / ROW_H));

        bool startedOnTrack =
            pressX >= TRACK_X0 - 12.0 &&
            pressX <= TRACK_X1 + 12.0 &&
            activeRow >= 0 &&
            activeRow < PARAM_COUNT;

        if (startedOnTrack && activeRow == id)
        {
            value = clamp(
                (currentX - TRACK_X0) / (TRACK_X1 - TRACK_X0),
                0.0,
                1.0
            );
        }

        float resetTop =
            uiResolution.y - PANEL_TOP - HEADER_H -
            float(PARAM_COUNT) * ROW_H - 3.0;

        float resetBottom = resetTop - 19.0;

        bool resetPressed =
            pressX >= PANEL_X + 176.0 &&
            pressX <= PANEL_X + 242.0 &&
            pressY >= resetBottom &&
            pressY <= resetTop;

        if (resetPressed)
        {
            value = defaultControl(id);
        }
    }

    fragColor = vec4(value, 0.0, 0.0, 1.0);
}