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

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 5; ++i)
    {
        v += a * noise(p);
        p = mat2(1.62, 1.11, -1.11, 1.62) * p;
        a *= 0.5;
    }

    return v;
}

vec2 barrel(vec2 uv, float amount)
{
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + amount * r2 + amount * 0.22 * r2 * r2;
    return p * 0.5 + 0.5;
}

vec3 sampleCA(sampler2D tex, vec2 uv, vec2 dir, float amount)
{
    vec2 off = dir * amount;

    float r = texture(tex, uv + off * 1.20).r;
    float g = texture(tex, uv + off * 0.25).g;
    float b = texture(tex, uv - off * 1.05).b;

    return vec3(r, g, b);
}

vec3 bloomish(sampler2D tex, vec2 uv, vec2 px)
{
    vec3 s = vec3(0.0);

    s += texture(tex, uv + px * vec2( 1.5,  0.0)).rgb;
    s += texture(tex, uv + px * vec2(-1.5,  0.0)).rgb;
    s += texture(tex, uv + px * vec2( 0.0,  1.5)).rgb;
    s += texture(tex, uv + px * vec2( 0.0, -1.5)).rgb;

    s += texture(tex, uv + px * vec2( 2.5,  2.5)).rgb;
    s += texture(tex, uv + px * vec2(-2.5,  2.5)).rgb;
    s += texture(tex, uv + px * vec2( 2.5, -2.5)).rgb;
    s += texture(tex, uv + px * vec2(-2.5, -2.5)).rgb;

    s *= 0.125;

    float luma = dot(s, vec3(0.299, 0.587, 0.114));
    return s * smoothstep(0.55, 1.0, luma);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float r = length(p);
    vec2 dir = normalize(p + 1e-5);

    float t = iTime;

    float drift = fbm(uv * 3.0 + vec2(t * 0.05, -t * 0.035));
    float heat = fbm(vec2(uv.x * 8.0, uv.y * 40.0 - t * 2.0));

    vec2 warp = vec2(
        sin(uv.y * 21.0 + t * 1.7),
        cos(uv.x * 17.0 - t * 1.2)
    );

    warp *= 0.0025 + 0.0025 * drift;
    warp.x += (heat - 0.5) * 0.006 * smoothstep(0.15, 1.1, r);

    vec2 duv = barrel(uv + warp, 0.075);

    float ca = 0.0025 + 0.0055 * smoothstep(0.15, 1.35, r);
    vec3 col = sampleCA(iChannel0, duv, dir, ca);

    vec3 glow = bloomish(iChannel0, duv, px);
    col += glow * 0.18;

    float vignette = smoothstep(1.45, 0.12, r);
    vignette *= 0.82 + 0.18 * smoothstep(0.95, 0.0, abs(p.x * 0.55) + abs(p.y));

    col *= vignette;

    float scan = sin((uv.y * iResolution.y) * 1.15 + t * 11.0);
    float scanFine = sin((uv.y * iResolution.y) * 3.0);
    col *= 0.965 + 0.025 * scan + 0.010 * scanFine;

    float grain = hash21(fragCoord + fract(t) * 911.17);
    float grainSoft = fbm(fragCoord * 0.35 + t * 13.0);
    col += (grain - 0.5) * 0.045;
    col += (grainSoft - 0.5) * 0.018;

    vec3 phase = vec3(0.0, 2.0, 4.0);
    col += 0.020 * sin(phase + t * 3.0 + uv.y * 80.0 + drift * 4.0);
    col += 0.010 * cos(phase.yzx + t * 1.2 + uv.x * 55.0);

    float pulse = 0.5 + 0.5 * sin(t * 0.7);
    col *= 0.985 + 0.035 * pulse * smoothstep(0.9, 0.0, r);

    col = max(col, vec3(0.0));

    col = pow(col, vec3(0.92));
    col = col / (col + vec3(0.18));
    col *= 1.18;

    col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), -0.08);

    float edge = smoothstep(0.94, 1.35, r);
    col += edge * vec3(0.025, 0.012, 0.035);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}