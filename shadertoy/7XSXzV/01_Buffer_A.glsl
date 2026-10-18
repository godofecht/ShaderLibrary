#define PI 3.14159265359

vec2 aspectUV(vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    return uv;
}

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float lum(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 sampleImage(vec2 uv)
{
    uv = uv * 0.5 + 0.5;
    uv.y = 1.0 - uv.y;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return vec3(0.0);

    return texture(iChannel0, uv).rgb;
}

vec3 sampleFeedback(vec2 uv)
{
    uv.x /= iResolution.x / iResolution.y;
    uv = uv * 0.5 + 0.5;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return vec3(0.0);

    return texture(iChannel1, uv).rgb;
}

vec2 rot(vec2 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c) * p;
}

vec3 imageNormal(vec2 p)
{
    vec2 e = vec2(1.0 / iResolution.y, 0.0);

    float c  = lum(sampleImage(p));
    float dx = lum(sampleImage(p + e.xy)) - lum(sampleImage(p - e.xy));
    float dy = lum(sampleImage(p + e.yx)) - lum(sampleImage(p - e.yx));

    return normalize(vec3(-dx * 7.0, -dy * 7.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = aspectUV(fragCoord);
    vec2 q = p;

    float t = iTime;
    float r = length(p);
    float a = atan(p.y, p.x);

    vec3 n = imageNormal(p);
    vec2 flow = n.xy * 0.065;

    float vortex = sin(a * 9.0 - r * 18.0 + t * 2.2);
    float pulse = sin(r * 32.0 - t * 5.0);

    q += flow;
    q += 0.018 * vec2(cos(a * 3.0 + t), sin(a * 4.0 - t));
    q += 0.012 * vortex * normalize(p + 0.001);
    q = rot(q, 0.035 * sin(t + r * 4.0));

    vec2 fbUV = p * (0.985 + 0.015 * sin(t + r * 8.0));
    fbUV = rot(fbUV, 0.006 + 0.01 * sin(t * 0.7));
    fbUV += flow * 0.45;

    vec3 fb = sampleFeedback(fbUV);

    float chroma = 0.005 + 0.012 * abs(vortex);
    vec3 img;
    img.r = sampleImage(q + chroma * n.xy).r;
    img.g = sampleImage(q).g;
    img.b = sampleImage(q - chroma * n.xy).b;

    float edge = length(n.xy);
    vec3 neon = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + a * 2.0 + r * 8.0 - t * 2.0);
    vec3 relief = img + neon * edge * 1.8;

    float scan = 0.92 + 0.08 * sin(fragCoord.y * 1.7 + t * 20.0);
    float sparkle = step(0.9975, hash(floor(fragCoord.xy * 0.8) + floor(t * 24.0)));

    vec3 col = mix(relief, fb * 1.04, 0.58);
    col += neon * pulse * 0.025;
    col += sparkle * neon * 0.8;

    float vignette = smoothstep(1.45, 0.15, r);
    col *= scan * vignette;

    col = pow(max(col, 0.0), vec3(0.88));
    col = col / (1.0 + col * 0.45);

    fragColor = vec4(col, 1.0);
}