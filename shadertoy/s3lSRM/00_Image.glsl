#define MAX_N 180
#define MAX_STEPS 120
#define MAX_DIST 30.0
#define EPS 0.001

float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r)
{
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float primeFlag(int n)
{
    if (n < 2) return 0.0;
    if (n == 2) return 1.0;
    if (n - 2 * (n / 2) == 0) return 0.0;

    for (int d = 3; d < 64; d += 2)
    {
        if (d * d > n) break;
        if (n - d * (n / d) == 0) return 0.0;
    }

    return 1.0;
}

vec3 numberPos(int n)
{
    float f = float(n);

    float theta = f * 0.37;
    float radius = 1.25
                 + 0.22 * sin(f * 0.113)
                 + 0.09 * sin(f * 0.031);

    float y = (f - float(MAX_N) * 0.5) * 0.030;

    float livingWobble = 0.055 * sin(iTime * 0.45 + f * 0.618);

    return vec3(
        (radius + livingWobble) * cos(theta),
        y,
        (radius + livingWobble) * sin(theta)
    );
}

float headValue()
{
    return clamp(2.0 + iTime * 1.15, 3.0, float(MAX_N - 3));
}

vec3 manifoldCenter()
{
    float head = headValue();
    int hn = int(floor(head));

    vec3 acc = vec3(0.0);
    float cnt = 0.0;

    for (int n = 2; n < MAX_N; ++n)
    {
        if (n <= hn)
        {
            acc += numberPos(n);
            cnt += 1.0;
        }
    }

    if (cnt > 0.0) acc /= cnt;

    int nextN = min(hn + 1, MAX_N - 1);
    float hf = fract(head);
    vec3 hp = mix(numberPos(hn), numberPos(nextN), hf);

    acc = mix(acc, hp, 0.35);

    return acc;
}

float mapScene(vec3 p)
{
    float head = headValue();
    vec3 center = manifoldCenter();
    float d = 100.0;

    for (int n = 2; n < MAX_N - 1; ++n)
    {
        float fn = float(n);

        if (fn < head + 1.0)
        {
            vec3 a = numberPos(n)     - center;
            vec3 b = numberPos(n + 1) - center;

            float appear = smoothstep(fn - 0.6, fn + 0.4, head);
            float prime = primeFlag(n);

            float tubeRadius = 0.022 * appear;
            float nodeRadius = mix(0.040, 0.110 + 0.020 * sin(iTime * 2.5 + fn), prime) * appear;

            d = smin(d, sdCapsule(p, a, b, tubeRadius), 0.065);
            d = smin(d, sdSphere(p - a, nodeRadius), mix(0.045, 0.130, prime));
        }
    }

    int hn = int(floor(head));
    float hf = fract(head);
    vec3 hp = mix(numberPos(hn), numberPos(hn + 1), hf) - center;
    d = smin(d, sdSphere(p - hp, 0.135), 0.16);

    return d;
}

float primeGlow(vec3 p)
{
    float head = headValue();
    vec3 center = manifoldCenter();
    float g = 0.0;

    for (int n = 2; n < MAX_N; ++n)
    {
        float fn = float(n);

        if (fn < head)
        {
            float prime = primeFlag(n);
            vec3 q = numberPos(n) - center;
            float d = length(p - q);

            float pulse = 0.65 + 0.35 * sin(iTime * 2.0 + fn * 1.7);
            g += prime * pulse * exp(-32.0 * d);
        }
    }

    return g;
}

float raymarch(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for (int i = 0; i < MAX_STEPS; ++i)
    {
        vec3 p = ro + rd * t;
        float h = mapScene(p);

        if (h < EPS * (1.0 + t))
        {
            return t;
        }

        t += h * 0.78;

        if (t > MAX_DIST) break;
    }

    return -1.0;
}

vec3 normalAt(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);

    return normalize(vec3(
        mapScene(p + e.xyy) - mapScene(p - e.xyy),
        mapScene(p + e.yxy) - mapScene(p - e.yxy),
        mapScene(p + e.yyx) - mapScene(p - e.yyx)
    ));
}

mat3 cameraLookAt(vec3 ro, vec3 ta)
{
    vec3 z = normalize(ta - ro);
    vec3 x = normalize(cross(vec3(0.0, 1.0, 0.0), z));
    vec3 y = cross(z, x);
    return mat3(x, y, z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;

    float orbit = iTime * 0.115;

    vec3 target = vec3(0.0);
    vec3 ro = vec3(
        4.2 * cos(orbit),
        1.25 + 0.35 * sin(iTime * 0.07),
        4.2 * sin(orbit)
    );

    mat3 cam = cameraLookAt(ro, target);
    vec3 rd = cam * normalize(vec3(uv, 1.85));

    vec3 col = vec3(0.015, 0.018, 0.026);
    col += 0.08 * vec3(0.16, 0.18, 0.28) * (1.0 - length(uv));

    float t = raymarch(ro, rd);

    if (t > 0.0)
    {
        vec3 p = ro + rd * t;
        vec3 n = normalAt(p);

        vec3 light = normalize(vec3(-0.35, 0.8, 0.45));
        float diff = clamp(dot(n, light), 0.0, 1.0);
        float rim = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 3.0);

        float g = primeGlow(p);

        vec3 base = mix(
            vec3(0.045, 0.060, 0.085),
            vec3(0.95, 0.72, 0.28),
            smoothstep(0.04, 0.42, g)
        );

        vec3 emissive = vec3(1.0, 0.62, 0.18) * g * 1.35;

        col = base * (0.18 + 1.15 * diff);
        col += emissive;
        col += rim * vec3(0.28, 0.36, 0.58);

        col = mix(col, vec3(0.015, 0.018, 0.026), 1.0 - exp(-0.018 * t * t));
    }

    col = pow(col, vec3(0.4545));
    fragColor = vec4(col, 1.0);
}