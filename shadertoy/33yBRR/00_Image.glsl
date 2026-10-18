#define TAU 6.28318530718

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float vnoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f*f*(3.0 - 2.0*f);

    float a = hash11(dot(i, vec2(127.1,311.7)));
    float b = hash11(dot(i+vec2(1,0), vec2(127.1,311.7)));
    float c = hash11(dot(i+vec2(0,1), vec2(127.1,311.7)));
    float d = hash11(dot(i+vec2(1,1), vec2(127.1,311.7)));

    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.55;
    mat2 m = mat2(1.6,-1.2,1.2,1.6);

    for(int i=0;i<6;i++)
    {
        v += a * vnoise(p);
        p = m * p;
        a *= 0.55;
    }
    return v;
}

float audioLow()
{
    float v = 0.0;
    for(int i=0;i<16;i++)
    {
        float f = float(i)/512.0;
        v += texture(iChannel0, vec2(f,0.25)).r;
    }
    return v/16.0;
}

float audioHigh()
{
    float v = 0.0;
    for(int i=64;i<128;i++)
    {
        float f = float(i)/512.0;
        v += texture(iChannel0, vec2(f,0.25)).r;
    }
    return v/64.0;
}

vec2 gradField(vec2 p, float t)
{
    float e = 0.002;

    float f1 = fbm(p + vec2(e,0) + 0.2*t);
    float f2 = fbm(p - vec2(e,0) + 0.2*t);
    float f3 = fbm(p + vec2(0,e) - 0.15*t);
    float f4 = fbm(p - vec2(0,e) - 0.15*t);

    return vec2(f1 - f2, f3 - f4)/(2.0*e);
}

vec2 curlField(vec2 p, float t)
{
    float e = 0.002;

    float n1 = fbm(p + vec2(0,e) + 0.3*t);
    float n0 = fbm(p - vec2(0,e) + 0.3*t);
    float m1 = fbm(p + vec2(e,0) - 0.2*t);
    float m0 = fbm(p - vec2(e,0) - 0.2*t);

    float dny = (n1 - n0)/(2.0*e);
    float dnx = (m1 - m0)/(2.0*e);

    return vec2(dny, -dnx);
}

vec3 palette(float t)
{
    return vec3(0.5) + 0.5*cos(TAU*(vec3(0.0,0.33,0.67) + t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    float bass   = audioLow();
    float treble = audioHigh();

    float t = iTime * (1.2 + 2.5*bass);

    float r = length(uv);
    float mask = exp(-6.0*r*r);

    uv += 0.4 * mask * curlField(uv*2.0, t);
    uv += 0.2 * mask * gradField(uv*2.5, t);
    uv += 0.15 * mask * curlField(uv*3.5, t + 1.0);

    float energy = length(uv);

    float n = fbm(uv*4.0 + t);
    float phase = sin(TAU*(uv.x*1.5 + uv.y*1.2) + 3.0*n + t);

    vec3 col = palette(0.4*phase + 0.7*n + 0.5*energy + 0.4*t);

    col *= 1.5 + 3.5*bass;
    col = pow(col, vec3(0.8 - 0.5*treble));
    col = 1.0 - exp(-col);

    float vign = smoothstep(1.5, 0.2, r);
    col *= 0.5 + 0.9*vign;

    fragColor = vec4(col,1.0);
}
