float noise3(vec3 x)
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);

#define hash3(p) fract(sin(1e3 * dot(p, vec3(1.0, 57.0, -13.7))) * 4375.5453)

    return mix(
        mix(
            mix(hash3(p + vec3(0,0,0)), hash3(p + vec3(1,0,0)), f.x),
            mix(hash3(p + vec3(0,1,0)), hash3(p + vec3(1,1,0)), f.x),
            f.y
        ),
        mix(
            mix(hash3(p + vec3(0,0,1)), hash3(p + vec3(1,0,1)), f.x),
            mix(hash3(p + vec3(0,1,1)), hash3(p + vec3(1,1,1)), f.x),
            f.y
        ),
        f.z
    );
}

#define noise(x) ((noise3(x) + noise3((x) + 11.5)) * 0.5)

float heightField(vec2 p, float t)
{
    float h = 0.0;
    h += 0.60 * noise(vec3(p * 1.00, t * 0.10));
    h += 0.30 * noise(vec3(p * 2.15 + 7.0, t * 0.16));
    h += 0.10 * noise(vec3(p * 4.30 + 2.0, t * 0.23));
    return h;
}

void mainImage(out vec4 O, vec2 U)
{
    vec2 R = iResolution.xy;
    float t = iTime;

    vec2 uv = U / R;
    vec2 p = U * 8.0 / R.y;

    float h = heightField(p, t);

    float iso = sin(6.2831853 * 10.0 * h);
    iso = smoothstep(1.0, 0.0, 0.5 * abs(iso) / fwidth(iso));

    float e = 2.0 / R.y * 8.0;

    float hx1 = heightField(p + vec2(e, 0.0), t);
    float hx2 = heightField(p - vec2(e, 0.0), t);
    float hy1 = heightField(p + vec2(0.0, e), t);
    float hy2 = heightField(p - vec2(0.0, e), t);

    vec2 grad = vec2(hx1 - hx2, hy1 - hy2);

    float depth = 18.0;
    vec3 normal = normalize(vec3(-grad * depth, 1.0));

    vec3 lightDir = normalize(vec3(-0.35, 0.55, 0.75));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);

    float diff = clamp(dot(normal, lightDir), 0.0, 1.0);
    float spec = pow(clamp(dot(reflect(-lightDir, normal), viewDir), 0.0, 1.0), 40.0);
    float rim = pow(1.0 - clamp(dot(normal, viewDir), 0.0, 1.0), 2.0);

    float centredHeight = h * 2.0 - 1.0;

    vec2 refractWarp = normal.xy * 0.075;
    vec2 heightWarp = grad * 0.20 * centredHeight;
    vec2 flowWarp = vec2(
        sin(6.0 * h + t),
        cos(7.0 * h - t * 0.7)
    ) * 0.012;

    vec2 warpedUV = uv + refractWarp + heightWarp + flowWarp;

    vec3 vidR = texture(iChannel0, warpedUV + normal.xy * 0.010).rgb;
    vec3 vidG = texture(iChannel0, warpedUV).rgb;
    vec3 vidB = texture(iChannel0, warpedUV - normal.xy * 0.010).rgb;

    vec3 video = vec3(vidR.r, vidG.g, vidB.b);

    vec3 contourColour = 0.5 + 0.5 * sin(12.0 * h + vec3(0.0, 2.1, -2.1));

    video *= 0.35 + 0.95 * diff;
    video += spec * 0.55;
    video += rim * 0.25;

    vec3 colour = mix(video, contourColour * video * 1.8, iso * 0.55);

    float vignette = smoothstep(1.3, 0.15, length((U - 0.5 * R) / R.y));
    colour *= vignette;

    O = vec4(colour, 1.0);
}