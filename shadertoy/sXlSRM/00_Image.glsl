#define LAYERS 96
#define DENSITY 95.0
#define PI 3.14159265359

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 4; ++i)
    {
        v += a * noise(p);
        p = mat2(1.7, 1.2, -1.2, 1.7) * p;
        a *= 0.5;
    }

    return v;
}

mat3 lookAt(vec3 ro, vec3 ta)
{
    vec3 f = normalize(ta - ro);
    vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
    vec3 u = cross(f, r);

    return mat3(r, u, f);
}

float reassembleAmount(float t)
{
    float x = fract(t / 8.0);

    float assemble =
        smoothstep(0.00, 0.18, x) *
        (1.0 - smoothstep(0.34, 0.52, x));

    assemble +=
        smoothstep(0.54, 0.78, x) *
        (1.0 - smoothstep(0.92, 1.00, x));

    return clamp(assemble, 0.0, 1.0);
}

float manifoldHeight(vec2 p)
{
    float t = iTime;

    float r = length(p);
    float a = atan(p.y, p.x);

    float h = 0.0;
    h += 0.18 * sin(r * 4.4 - t * 1.15);
    h += 0.08 * sin(a * 7.0 + r * 2.0 + t * 0.55);
    h += 0.12 * fbm(p * 1.8 + vec2(t * 0.035, -t * 0.02));

    return h;
}

float primeish(vec2 cell)
{
    float n = abs(cell.x * 17.0 + cell.y * 31.0);
    float h = hash12(cell * 2.7 + 19.3);

    float sieve =
        step(0.08, abs(fract(n / 2.0) - 0.5)) *
        step(0.08, abs(fract(n / 3.0) - 0.5)) *
        step(0.08, abs(fract(n / 5.0) - 0.5)) *
        step(0.08, abs(fract(n / 7.0) - 0.5));

    return max(sieve * step(0.42, h), step(0.965, h));
}

vec3 backgroundColor(vec2 uv, vec3 rd)
{
    vec3 bg = vec3(0.006, 0.009, 0.015);

    bg += vec3(0.06, 0.08, 0.13) * pow(max(0.0, 1.0 - length(uv)), 2.0);
    bg += vec3(0.10, 0.13, 0.18) * pow(max(0.0, rd.y * 0.5 + 0.5), 2.0);

    return bg;
}

vec3 render(vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float camT = iTime * 0.22;

    vec3 ro = vec3(
        2.7 * sin(camT),
        0.65 + 0.18 * sin(iTime * 0.47),
        2.7 * cos(camT)
    );

    vec3 ta = vec3(
        0.15 * sin(iTime * 0.17),
        0.0,
        0.15 * cos(iTime * 0.13)
    );

    vec3 rd = normalize(lookAt(ro, ta) * vec3(uv, 1.35));

    vec3 bg = backgroundColor(uv, rd);
    vec3 col = bg;

    float assemble = reassembleAmount(iTime);
    float explode = 1.0 - assemble;

    for (int i = LAYERS; i > 0; --i)
    {
        float layer = float(i) / float(LAYERS);
        float planeY = mix(-0.42, 0.48, layer);

        float denom = rd.y;

        if (abs(denom) < 0.0001)
        {
            continue;
        }

        float dist = (planeY - ro.y) / denom;

        if (dist <= 0.0)
        {
            continue;
        }

        vec3 pos = ro + rd * dist;

        float h = manifoldHeight(pos.xz);
        float shell = 1.0 - smoothstep(0.00, 0.035, abs(pos.y - h));

        if (shell <= 0.0)
        {
            continue;
        }

        vec2 gridPos = pos.xz * DENSITY;
        vec2 baseCell = floor(gridPos);

        float bestCore = 0.0;
        float bestHalo = 0.0;
        float bestSeed = 0.0;

        for (int ox = -1; ox <= 1; ++ox)
        {
            for (int oz = -1; oz <= 1; ++oz)
            {
                vec2 cell = baseCell + vec2(float(ox), float(oz));

                float exists = primeish(cell);

                if (exists < 0.5)
                {
                    continue;
                }

                vec2 home = (cell + 0.5) / DENSITY;

                float seed = hash12(cell * 0.91 + 4.2);
                float angle = 6.2831853 * hash12(cell * 1.37 + 8.8);
                float spin = iTime * (0.8 + 1.4 * seed);

                vec2 dir = vec2(cos(angle + spin), sin(angle + spin));

                vec2 chaos =
                    dir * ((0.15 + 1.8 * seed) * explode / DENSITY) +
                    vec2(
                        sin(iTime * 1.5 + seed * 19.0),
                        cos(iTime * 1.1 + seed * 23.0)
                    ) * (0.55 * explode / DENSITY);

                vec2 pointPos = home + chaos;

                float d = length(pos.xz - pointPos) * DENSITY;

                float core = smoothstep(0.44, 0.02, d);
                float halo = smoothstep(1.60, 0.05, d);

                if (core > bestCore)
                {
                    bestCore = core;
                    bestHalo = halo;
                    bestSeed = seed;
                }
            }
        }

        if (bestCore > 0.01)
        {
            vec2 e = vec2(0.018, 0.0);

            float hx = manifoldHeight(pos.xz + e.xy) - manifoldHeight(pos.xz - e.xy);
            float hz = manifoldHeight(pos.xz + e.yx) - manifoldHeight(pos.xz - e.yx);

            vec3 n = normalize(vec3(-hx, 0.035, -hz));
            vec3 lightDir = normalize(vec3(-0.5, 0.75, -0.45));

            float diff = clamp(dot(n, lightDir), 0.0, 1.0);
            float rim = pow(1.0 - max(dot(n, -rd), 0.0), 2.4);

            float fog = exp(-0.075 * dist * dist);

            vec3 cold = vec3(0.08, 0.13, 0.22);
            vec3 gold = vec3(1.00, 0.66, 0.22);
            vec3 white = vec3(1.00, 0.86, 0.58);

            vec3 material = mix(cold, gold, pow(layer, 1.4));
            material *= 0.30 + 1.25 * diff;
            material += white * bestHalo * (0.30 + 0.90 * explode);
            material += vec3(0.30, 0.45, 0.70) * rim * 0.25;

            float alpha = bestCore * shell * fog;

            col = mix(col, material, clamp(alpha * 1.35, 0.0, 1.0));
            col += gold * bestHalo * shell * fog * (0.06 + 0.12 * explode);

            break;
        }
    }

    float vignette = smoothstep(1.35, 0.25, length(uv));
    col *= 0.72 + 0.28 * vignette;

    col = col / (1.0 + col);
    col = pow(col, vec3(1.0 / 2.2));

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = render(fragCoord);
    fragColor = vec4(col, 1.0);
}