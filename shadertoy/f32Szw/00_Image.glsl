#define H 16

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float weight(int layer, int i, int j)
{
    float h = hash11(float(layer) * 97.31 + float(i) * 17.17 + float(j) * 3.113);
    return (h * 2.0 - 1.0) * 1.35;
}

float bias(int layer, int i)
{
    float h = hash11(float(layer) * 71.13 + float(i) * 11.71 + 4.2);
    return (h * 2.0 - 1.0) * 0.45;
}

float act(float x)
{
    return tanh(x);
}

void layer3toH(vec3 x, out float h[H])
{
    for (int i = 0; i < H; ++i)
    {
        float s = bias(0, i);
        s += x.x * weight(0, i, 0);
        s += x.y * weight(0, i, 1);
        s += x.z * weight(0, i, 2);
        h[i] = act(s);
    }
}

void layerHtoH(float a[H], out float b[H], int layer)
{
    for (int i = 0; i < H; ++i)
    {
        float s = bias(layer, i);

        for (int j = 0; j < H; ++j)
        {
            s += a[j] * weight(layer, i, j);
        }

        b[i] = act(s);
    }
}

vec3 layerHtoRGB(float h[H])
{
    vec3 y = vec3(0.0);

    for (int j = 0; j < H; ++j)
    {
        y.r += h[j] * weight(4, 0, j);
        y.g += h[j] * weight(4, 1, j);
        y.b += h[j] * weight(4, 2, j);
    }

    y.r += bias(4, 0);
    y.g += bias(4, 1);
    y.b += bias(4, 2);

    return 0.5 + 0.5 * tanh(y);
}

vec3 neuralField(vec2 uv, float t)
{
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    vec3 inputVector = vec3(
        uv.x * 1.6 + 0.25 * sin(t + r * 4.0),
        uv.y * 1.6 + 0.25 * cos(t * 0.8 + a * 3.0),
        sin(t * 0.35) + cos(r * 6.0) * 0.25
    );

    float h0[H];
    float h1[H];
    float h2[H];
    float h3[H];

    layer3toH(inputVector, h0);
    layerHtoH(h0, h1, 1);
    layerHtoH(h1, h2, 2);
    layerHtoH(h2, h3, 3);

    vec3 col = layerHtoRGB(h3);

    float vignette = smoothstep(1.45, 0.15, r);
    float pulse = 0.5 + 0.5 * sin(12.0 * r - t * 3.0);

    col += 0.12 * pulse * vec3(0.3, 0.6, 1.0);
    col *= vignette;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float t = iTime;

    vec3 col = neuralField(uv, t);

    col = pow(col, vec3(0.85));

    fragColor = vec4(col, 1.0);
}