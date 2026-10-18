#define EDGE_SCALE  1.0
#define INJECT      0.85
#define DIFFUSE     0.22
#define DECAY       0.965
#define THRESHOLD   0.025
#define FLOW        0.45
#define GLOW_SIZE   1.0

float luma(vec3 c)
{
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float lookupSource(vec2 uv, vec2 px, float x, float y)
{
    return luma(texture(iChannel1, uv + vec2(x, y) * px * GLOW_SIZE).rgb);
}

float sobel(vec2 uv, vec2 px)
{
    float gx = 0.0;
    gx += -1.0 * lookupSource(uv, px, -1.0, -1.0);
    gx += -2.0 * lookupSource(uv, px, -1.0,  0.0);
    gx += -1.0 * lookupSource(uv, px, -1.0,  1.0);
    gx +=  1.0 * lookupSource(uv, px,  1.0, -1.0);
    gx +=  2.0 * lookupSource(uv, px,  1.0,  0.0);
    gx +=  1.0 * lookupSource(uv, px,  1.0,  1.0);

    float gy = 0.0;
    gy += -1.0 * lookupSource(uv, px, -1.0, -1.0);
    gy += -2.0 * lookupSource(uv, px,  0.0, -1.0);
    gy += -1.0 * lookupSource(uv, px,  1.0, -1.0);
    gy +=  1.0 * lookupSource(uv, px, -1.0,  1.0);
    gy +=  2.0 * lookupSource(uv, px,  0.0,  1.0);
    gy +=  1.0 * lookupSource(uv, px,  1.0,  1.0);

    return max(length(vec2(gx, gy)) - THRESHOLD, 0.0) * EDGE_SCALE;
}

vec2 flowField(vec2 uv)
{
    float t = iTime * 0.18;

    float a =
        sin(uv.x * 17.0 + t) +
        cos(uv.y * 19.0 - t * 1.3) +
        sin((uv.x + uv.y) * 11.0 + t * 0.7);

    return vec2(cos(a), sin(a)) * FLOW;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    vec2 f = flowField(uv) * px;

    vec3 c  = texture(iChannel0, uv).rgb;

    vec3 l  = texture(iChannel0, uv - vec2(px.x, 0.0) - f).rgb;
    vec3 r  = texture(iChannel0, uv + vec2(px.x, 0.0) - f).rgb;
    vec3 d  = texture(iChannel0, uv - vec2(0.0, px.y) - f).rgb;
    vec3 u  = texture(iChannel0, uv + vec2(0.0, px.y) - f).rgb;

    vec3 blur = (l + r + d + u) * 0.25;
    vec3 diffused = mix(c, blur, DIFFUSE);

    float edge = sobel(uv, px);
    edge = edge * edge;

    vec3 source = vec3(edge);

    vec3 outCol = diffused * DECAY + source * INJECT;

    if (iFrame < 2)
    {
        outCol = vec3(0.0);
    }

    fragColor = vec4(outCol, 1.0);
}