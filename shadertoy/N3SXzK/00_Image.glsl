#define PI 3.14159265359
#define TAU 6.28318530718

mat2 rot(float a)
{
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash(float n)
{
    return fract(sin(n) * 43758.5453123);
}

float line(float x, float w)
{
    return 1.0 - smoothstep(w, w + 0.006, abs(x));
}

float grid(float v, float f, float w)
{
    return line(fract(v * f) - 0.5, w);
}

float ray(vec2 p, float n, float sharp)
{
    float a = atan(p.y, p.x);
    float r = length(p);
    return pow(abs(cos(a * n)), sharp) / max(r * 2.3, 0.035);
}

vec3 palette(float t)
{
    return 0.55 + 0.45 * cos(TAU * (vec3(0.00, 0.33, 0.67) + t));
}

float plasma(vec2 p, float t)
{
    float v = 0.0;

    v += sin(p.x * 3.0 + t);
    v += sin(p.y * 4.0 - t * 1.2);
    v += sin((p.x + p.y) * 5.0 + t * 0.7);
    v += sin(length(p) * 8.0 - t * 2.5);

    return v * 0.25;
}

vec2 kaleido(vec2 p, float sides)
{
    float a = atan(p.y, p.x);
    float r = length(p);

    float sector = TAU / sides;
    a = mod(a + sector * 0.5, sector) - sector * 0.5;
    a = abs(a);

    return vec2(cos(a), sin(a)) * r;
}

vec3 tunnel(vec2 p)
{
    p.x *= iResolution.x / iResolution.y;

    float t = iTime;

    float r = length(p);
    float a = atan(p.y, p.x);

    float pulse = 0.5 + 0.5 * sin(t * 1.7);
    float aperture = 0.20 + 0.055 * pulse;

    vec2 kp = kaleido(p * rot(t * 0.17), 7.0 + floor(3.0 * pulse));
    kp += 0.045 * vec2(
        sin(kp.y * 9.0 + t * 2.0),
        cos(kp.x * 8.0 - t * 1.7)
    );

    float kr = length(kp);
    float ka = atan(kp.y, kp.x);

    float z = 1.0 / max(kr, 0.035);
    float spiral = ka / TAU + z * 0.035 + sin(z * 0.18 + t) * 0.035;

    vec2 q = vec2(spiral, z);
    q.y += t * (0.80 + 0.25 * sin(t * 0.41));
    q.x += sin(q.y * 0.45 + t * 1.3) * 0.08;

    vec3 col = vec3(0.0);

    float thick = 0.026 + 0.018 * sin(t * 1.1 + z * 0.13);

    float plaidA =
        grid(q.x, 5.0 + 2.0 * sin(t * 0.31), thick) +
        grid(q.y, 1.8 + 0.6 * cos(t * 0.27), thick);

    float plaidB =
        grid(q.x + 0.19 + sin(t) * 0.03, 9.0, 0.016) +
        grid(q.y + 0.31 + cos(t) * 0.04, 3.3, 0.018);

    float plaidC =
        grid(q.x + 0.07, 15.0 + 4.0 * sin(t * 0.23), 0.010) +
        grid(q.y + 0.11, 5.2 + 2.0 * cos(t * 0.19), 0.011);

    float hot =
        grid(q.x + q.y * 0.045 + t * 0.03, 3.0, 0.035) +
        grid(q.x - q.y * 0.030 - t * 0.02, 4.0, 0.027);

    vec3 acidA = palette(q.y * 0.030 + t * 0.080);
    vec3 acidB = palette(q.x * 1.700 - t * 0.120 + 0.25);
    vec3 acidC = palette(plasma(kp * 3.0, t) + z * 0.018 - t * 0.050);

    col += acidA * plaidA * 1.35;
    col += acidB * plaidB * 1.15;
    col += acidC * plaidC * 1.35;
    col += palette(q.x * 2.0 + q.y * 0.05 + t * 0.12) * hot * 0.95;

    float tunnelMask = smoothstep(aperture, aperture + 0.045, r);
    col *= tunnelMask;

    float rim =
        smoothstep(aperture, aperture + 0.020, r) *
        (1.0 - smoothstep(aperture + 0.040, aperture + 0.105, r));

    col += palette(t * 0.13 + r * 2.5) * rim * 2.0;

    vec2 sp = p * rot(t * 1.4 + sin(t * 0.3) * 0.5);

    float burst =
        ray(sp, 7.0, 11.0) * 0.55 +
        ray(sp * rot(PI / 7.0), 14.0, 24.0) * 0.36 +
        ray(sp * rot(PI / 11.0), 21.0, 34.0) * 0.18;

    float core = exp(-dot(p, p) * 95.0);
    float halo = exp(-r * 4.7);
    float ring = sin(r * 72.0 - t * 8.0) * 0.5 + 0.5;
    ring *= exp(-r * 3.7);

    col += palette(t * 0.21 + a / TAU) * burst * 0.90;
    col += palette(t * 0.12 + r * 1.8) * halo * 0.70;
    col += palette(t * 0.30 + r * 5.0) * ring * 0.20;
    col += vec3(1.0, 0.86, 0.52) * core * 7.5;

    float fog = exp(-kr * 1.7);
    col += palette(t * 0.08 + plasma(p * 2.0, t)) * fog * 0.22;

    return col;
}

vec3 render(vec2 p)
{
    vec3 col = tunnel(p);

    vec2 warp = vec2(
        sin(p.y * 8.0 + iTime * 2.0),
        cos(p.x * 7.0 - iTime * 1.7)
    ) * 0.012;

    col += tunnel(p + warp) * 0.28;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;

    float t = iTime;

    float wob =
        sin(uv.y * 48.0 + t * 5.0) * 0.0045 +
        sin(uv.y * 137.0 - t * 9.0) * 0.0018;

    wob += (hash(vec2(floor(uv.y * 260.0), floor(t * 24.0))) - 0.5) * 0.006;
    p.x += wob;

    float zoom = 1.0 + 0.055 * sin(t * 1.4) + 0.025 * sin(t * 3.7);
    p *= zoom;

    p *= rot(0.035 * sin(t * 0.8));

    float ca = 0.006 + 0.006 * sin(t * 0.9);
    vec3 col;

    col.r = render(p + vec2( ca, 0.0)).r;
    col.g = render(p + vec2( 0.0, 0.0)).g;
    col.b = render(p + vec2(-ca, 0.0)).b;

    float scan = 0.76 + 0.24 * sin(uv.y * iResolution.y * PI);
    float grain = hash(fragCoord.xy + t * 80.0) * 0.065;

    float tear = smoothstep(0.985, 1.0, sin(uv.y * 17.0 + t * 3.2));
    col += tear * vec3(0.14, 0.03, 0.20);

    col = col * scan + grain;

    float vignette = smoothstep(1.35, 0.20, length(p));
    col *= 0.82 + 0.38 * vignette;

    col *= vec3(1.13, 0.90, 1.08);

    col = max(col, 0.0);
    col = col / (1.0 + col * 0.34);
    col = pow(col, vec3(0.72));

    float flash = 0.94 + 0.06 * sin(t * 9.0 + sin(t * 2.0));
    col *= flash;

    fragColor = vec4(col, 1.0);
}