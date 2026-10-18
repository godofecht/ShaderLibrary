#define TAU 6.28318530718

#define ITER_FIELD 8
#define ITER_LAYERS 7

#define DOMAIN_WARP 0.6
#define RADIAL_DRIFT 0.8
#define ANGULAR_DRIFT 0.4

#define FRACTAL_SCALE 1.7
#define AMP_DECAY 0.65

#define ENERGY_GAIN 1.4
#define EXPOSURE 1.5

vec3 palette(float t)
{
    vec3 a = vec3(0.5);
    vec3 b = vec3(0.5);
    vec3 c = vec3(1.0);
    vec3 d = vec3(0.1, 0.3, 0.6);
    return a + b * cos(TAU * (c * t + d));
}

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float field(vec2 p)
{
    float accum = 0.0;
    float prev = 0.0;
    float weightSum = 0.0;

    float strength = 0.6 + 0.4 * sin(iTime * 0.37);

    for (int i = 0; i < ITER_FIELD; i++)
    {
        float mag = dot(p, p);
        p = abs(p) / mag - 0.45;

        float fi = float(i);
        float w = exp(-fi * 0.35);

        float diff = abs(mag - prev);
        float pulse = exp(-strength * diff * diff);

        accum += pulse * w;
        weightSum += w;

        prev = mag;

        p *= rot(0.3 + fi * 0.2 + iTime * 0.1);
    }

    return accum / weightSum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) /
              min(iResolution.x, iResolution.y);

    float r = length(uv);
    float a = atan(uv.y, uv.x);

    float radialWarp =
        sin(r * 6.0 - iTime * RADIAL_DRIFT) *
        DOMAIN_WARP;

    float angularWarp =
        sin(a * 8.0 + iTime * ANGULAR_DRIFT) *
        DOMAIN_WARP;

    r += radialWarp;
    a += angularWarp;

    vec2 p = r * vec2(cos(a), sin(a));

    float globalDrift =
        sin(iTime * 0.2) *
        cos(r * 4.0 + iTime * 0.5);

    p *= rot(globalDrift);

    float zoom = exp(sin(iTime * 0.25) * 0.8);
    p *= zoom;

    vec3 color = vec3(0.0);
    float amp = 1.0;

    for (int i = 0; i < ITER_LAYERS; i++)
    {
        float fi = float(i);

        p *= rot(0.4 + fi * 0.3 + sin(iTime * 0.3 + fi));

        vec2 shear =
            vec2(
                sin(p.y * 3.0 + iTime),
                cos(p.x * 3.0 - iTime)
            ) * 0.2;

        p += shear;

        float f = field(p);

        float energy =
            pow(abs(f), 1.5 + sin(fi + iTime * 0.2));

        vec3 col = palette(
            f + fi * 0.17 + iTime * 0.12
        );

        color += col * energy * amp;

        p *= FRACTAL_SCALE;
        amp *= AMP_DECAY;
    }

    color = pow(color, vec3(0.75));
    color *= ENERGY_GAIN;

    color = 1.0 - exp(-color * EXPOSURE);

    fragColor = vec4(color, 1.0);
}
