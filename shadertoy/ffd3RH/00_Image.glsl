#define PI  3.14159265358979323846
#define TAU 6.28318530717958647692
#define N   32.0

vec3 hsv2rgb(vec3 c)
{
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float sdSegment(vec2 p, vec2 a, vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;

    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);

    return length(pa - ba * h);
}

float line(float d, float w)
{
    return 1.0 - smoothstep(w, w + fwidth(d), abs(d));
}

float stroke(float d, float w)
{
    return 1.0 - smoothstep(w, w + fwidth(d), d);
}

float signedBin(float k)
{
    return k <= N * 0.5 ? k : k - N;
}

vec3 dftCell(vec2 f, float k, float n, float x)
{
    float ks = signedBin(k);

    float shift = iTime * 1.25;

    float phaseCell = TAU * (ks * n / N - ks * shift / N);
    float phaseCont = TAU * (ks * x / N - ks * shift / N);

    vec2 z = vec2(cos(phaseCell), sin(phaseCell));

    float hue = fract(phaseCell / TAU);
    vec3 col = hsv2rgb(vec3(hue, 0.78, 0.82));

    float realValue = cos(phaseCell);
    float shade = 0.55 + 0.35 * realValue;

    col *= shade;

    vec2 p = f - 0.5;

    float axis = line(f.y - 0.5, 0.006);
    col = mix(col, vec3(0.015), axis * 0.35);

    float realCurve = 0.5 + 0.34 * cos(phaseCont);
    float imagCurve = 0.5 + 0.34 * sin(phaseCont);

    float realLine = line(f.y - realCurve, 0.018);
    float imagLine = line(f.y - imagCurve, 0.013);

    col = mix(col, vec3(0.05, 0.40, 1.00), imagLine * 0.62);
    col = mix(col, vec3(1.00, 1.00, 1.00), realLine * 0.86);

    float circle = line(length(p) - 0.29, 0.012);
    col += vec3(circle * 0.08);

    float ray = stroke(sdSegment(p, vec2(0.0), z * 0.26), 0.010);
    float dotp = stroke(length(p - z * 0.26), 0.034);

    col = mix(col, vec3(1.0), ray * 0.32);
    col = mix(col, vec3(1.0), dotp * 0.88);

    vec2 edge = min(f, 1.0 - f);
    float border = 1.0 - smoothstep(0.0, 0.018, min(edge.x, edge.y));
    col = mix(col, vec3(0.0), border * 0.32);

    return col;
}

vec3 renderMatrix(vec2 q)
{
    vec2 g = q * N;

    float n = floor(g.x);
    float row = floor((1.0 - q.y) * N);
    float k = clamp(row, 0.0, N - 1.0);

    vec2 f = fract(g);

    vec3 col = dftCell(f, k, n, g.x);

    if (iMouse.z > 0.0)
    {
        vec2 mq = (iMouse.xy - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y) + 0.5;

        if (mq.x >= 0.0 && mq.x <= 1.0 && mq.y >= 0.0 && mq.y <= 1.0)
        {
            float selectedK = floor((1.0 - mq.y) * N);
            float selected = 1.0 - step(0.5, abs(k - selectedK));

            col *= mix(0.22, 1.0, selected);

            float rowTop = 1.0 - selectedK / N;
            float rowBot = 1.0 - (selectedK + 1.0) / N;

            float hi = max(line(q.y - rowTop, 0.003), line(q.y - rowBot, 0.003));
            col = mix(col, vec3(1.0), hi * 0.75);
        }
    }

    return col;
}

vec3 renderZoom(vec2 uv)
{
    vec2 mq = (iMouse.xy - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y) + 0.5;

    float selectedK = floor((1.0 - mq.y) * N);
    selectedK = clamp(selectedK, 0.0, N - 1.0);

    vec2 p = uv;

    float nFloat = p.x * N;
    float n = floor(nFloat);
    vec2 f = vec2(fract(nFloat), p.y);

    vec3 col = dftCell(f, selectedK, n, nFloat);

    float ks = signedBin(selectedK);
    float cycles = abs(ks);

    float band = smoothstep(0.0, 0.08, p.y) * smoothstep(1.0, 0.92, p.y);
    col *= band;

    float centre = line(p.y - 0.5, 0.002);
    col = mix(col, vec3(0.0), centre * 0.25);

    float border = max(line(p.y - 0.04, 0.004), line(p.y - 0.96, 0.004));
    col = mix(col, vec3(1.0), border * 0.45);

    float dc = 1.0 - smoothstep(0.0, 0.5, cycles);
    col = mix(col, vec3(0.9, 0.9, 0.9), dc * 0.08);

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 res = iResolution.xy;
    float s = min(res.x, res.y);

    vec2 q = (fragCoord - 0.5 * res) / s + 0.5;
    vec2 uv = fragCoord / res;

    vec3 col = vec3(0.008, 0.009, 0.012);

    bool inside = q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0;

    if (inside)
    {
        col = renderMatrix(q);
    }

    if (iMouse.z > 0.0)
    {
        vec2 mq = (iMouse.xy - 0.5 * res) / s + 0.5;

        if (mq.x >= 0.0 && mq.x <= 1.0 && mq.y >= 0.0 && mq.y <= 1.0)
        {
            col = renderZoom(uv);
        }
    }

    float vignette = smoothstep(1.25, 0.25, length((uv - 0.5) * vec2(res.x / res.y, 1.0)));
    col *= vignette;

    col = pow(col, vec3(0.92));

    fragColor = vec4(col, 1.0);
}