#define PI 3.14159265359

mat2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float line(float x, float w)
{
    return 1.0 - smoothstep(w, w + 0.005, abs(x));
}

float grid(float v, float f, float w)
{
    return line(fract(v * f) - 0.5, w);
}

float ray(vec2 p, float n, float sharp)
{
    float a = atan(p.y, p.x);
    float r = length(p);
    return pow(abs(cos(a * n)), sharp) / max(r * 2.6, 0.035);
}

float readControl(int id)
{
    return texelFetch(iChannel0, ivec2(id, 0), 0).r;
}

vec3 hueRotate(vec3 c, float angle)
{
    float co = cos(angle);
    float si = sin(angle);

    return max(
        vec3(
            c.r * (0.299 + 0.701 * co + 0.168 * si) +
            c.g * (0.587 - 0.587 * co + 0.330 * si) +
            c.b * (0.114 - 0.114 * co - 0.497 * si),

            c.r * (0.299 - 0.299 * co - 0.328 * si) +
            c.g * (0.587 + 0.413 * co + 0.035 * si) +
            c.b * (0.114 - 0.114 * co + 0.292 * si),

            c.r * (0.299 - 0.300 * co + 1.250 * si) +
            c.g * (0.587 - 0.588 * co - 1.050 * si) +
            c.b * (0.114 + 0.886 * co - 0.203 * si)
        ),
        0.0
    );
}

vec3 renderTunnel(vec2 p)
{
    float scale     = mix(0.10, 0.70, readControl(0));
    float lengthExp = mix(0.25, 2.00, readControl(1));
    float detail    = mix(3.0, 30.0, readControl(2));
    float turb      = mix(0.0, 2.0, readControl(3));
    float freq      = mix(0.25, 2.50, readControl(4));
    float speed     = mix(0.0, 3.0, readControl(5));
    int layers      = int(floor(mix(1.0, 12.0, readControl(6)) + 0.5));
    float hueShift  = (readControl(7) - 0.5) * 2.0 * PI;
    float glow      = mix(0.25, 2.0, readControl(8));

    p.x *= iResolution.x / iResolution.y;
    p *= scale / 0.30;

    float t = iTime * speed;
    float r = length(p);
    float rSafe = max(r, 0.045);
    float zBase = pow(1.0 / rSafe, lengthExp);
    float aBase = atan(p.y, p.x) / (2.0 * PI);
    float detailWidth = mix(0.028, 0.006, (detail - 3.0) / 27.0);

    vec3 col = vec3(0.0);

    for (int i = 0; i < 12; ++i)
    {
        if (i >= layers)
        {
            break;
        }

        float fi = float(i);
        float layerFade = exp(-fi * 0.22);

        float a = aBase;
        float z = zBase * (1.0 + fi * (0.18 + 0.05 * freq));

        a += sin(z * 0.18 * freq + fi * 1.71 + t * 0.70) * 0.014 * turb;
        z += sin(a * 2.0 * PI * (2.6 + 0.5 * fi) * freq - t * 0.95) * 0.45 * turb;

        vec2 q = vec2(a, z);
        vec2 m = q;
        m.y += t * (0.55 + 0.05 * fi);
        m.x += sin(t * 0.28 + fi * 0.43) * 0.008 * turb;

        float amber =
            grid(m.x, (5.8 + fi * 0.12) * freq, 0.040) +
            grid(m.y, (1.85 + fi * 0.05) * freq, 0.040) +
            grid(m.x + 0.055, (5.8 + fi * 0.12) * freq, 0.022) +
            grid(m.y + 0.055, (1.85 + fi * 0.05) * freq, 0.022);

        float orange =
            grid(m.x + 0.22, (8.8 + fi * 0.20) * freq, 0.020) +
            grid(m.y + 0.28, (3.2 + fi * 0.08) * freq, 0.020);

        float red =
            grid(q.x + 0.12 + fi * 0.007, 3.0 * freq, 0.032) +
            grid(q.x + 0.24 + fi * 0.009, 3.0 * freq, 0.032) +
            grid(q.y + 0.10 + fi * 0.030, 0.82 * freq, 0.032) +
            grid(q.y + 0.22 + fi * 0.036, 0.82 * freq, 0.032);

        float green =
            grid(q.x + 0.07 + fi * 0.010, 10.0 * freq, 0.013) +
            grid(q.y + 0.05 + fi * 0.018, 2.9 * freq, 0.013);

        float fine =
            grid(q.x + fi * 0.015, detail * 0.62 * freq, detailWidth) +
            grid(q.y + fi * 0.028, detail * 0.21 * freq, detailWidth);

        col += vec3(1.00, 0.50, 0.00) * amber  * 1.22 * layerFade;
        col += vec3(1.00, 0.30, 0.00) * orange * 1.00 * layerFade;
        col += vec3(0.55, 0.02, 0.00) * red    * 0.90 * layerFade;
        col += vec3(0.02, 0.30, 0.08) * green  * 0.48 * layerFade;
        col += vec3(1.00, 0.65, 0.25) * fine   * 0.15 * layerFade;
    }

    float aperture = 0.28;
    float mask = smoothstep(aperture, aperture + 0.035, r);
    col *= mask;

    float rim =
        smoothstep(aperture, aperture + 0.02, r) *
        (1.0 - smoothstep(aperture + 0.05, aperture + 0.09, r));

    col += vec3(1.0, 0.30, 0.0) * rim * 1.15 * glow;

    vec2 sp = p * rot(t * 1.25 + turb * 0.15);
    float spokeCount = 8.0 + floor(detail * 0.20);

    float burst =
        ray(sp, spokeCount, 13.0 + detail * 0.25) * 0.75 +
        ray(sp * rot(PI / max(spokeCount, 1.0)), spokeCount, 28.0 + detail * 0.40) * 0.35;

    float core = exp(-dot(p, p) * (85.0 / max(scale, 0.12)));
    float halo = exp(-length(p) * (6.0 / max(scale, 0.12)));

    col += vec3(1.0, 0.42, 0.00) * burst * 0.55 * glow;
    col += vec3(1.0, 0.50, 0.04) * halo  * 0.42 * glow;
    col += vec3(1.0, 0.82, 0.45) * core  * 6.5  * glow;

    col = hueRotate(col, hueShift);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;

    float speed = mix(0.0, 3.0, readControl(5));
    float turb  = mix(0.0, 2.0, readControl(3));

    float wob = sin(uv.y * 45.0 + iTime * 4.0 * speed) * (0.004 + 0.002 * turb);
    wob += (hash(vec2(floor(uv.y * 230.0), floor(iTime * 24.0 * max(speed, 0.25)))) - 0.5) * (0.004 + 0.003 * turb);
    p.x += wob;

    vec3 col;
    col.r = renderTunnel(p + vec2( 0.006, 0.0)).r;
    col.g = renderTunnel(p).g;
    col.b = renderTunnel(p + vec2(-0.006, 0.0)).b;

    float scan = 0.82 + 0.18 * sin(uv.y * iResolution.y * PI);
    float grain = hash(fragCoord.xy + iTime * 70.0 * max(speed, 0.25)) * 0.045;

    col = col * scan + grain;
    col *= 1.08 - length(p) * 0.13;

    col *= vec3(1.08, 0.92, 0.78);
    col = pow(max(col, 0.0), vec3(0.78));

    fragColor = vec4(col, 1.0);
}