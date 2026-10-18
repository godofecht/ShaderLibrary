#define TAU 6.28318530718

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 rot(vec2 p, float a)
{
    float c = cos(a), s = sin(a);
    return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
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
    for(int i=0;i<5;i++)
    {
        v += a * vnoise(p);
        p = m * p;
        a *= 0.55;
    }
    return v;
}

vec2 mouseUV()
{
    vec2 center = vec2(0.0);
    float hasPos = step(0.5, iMouse.x + iMouse.y);
    vec2 m = (iMouse.xy - 0.5*iResolution.xy) / iResolution.y;
    return mix(center, m, hasPos);
}

float rippleHeight(vec2 p, float t)
{
    vec2 c = mouseUV();
    vec2 d = p - c;
    float r = length(d) + 1e-6;

    float k = TAU * 9.0;
    float wave = sin(k*r - TAU*2.2*t);
    float decay = exp(-2.0*r);
    float core = 1.0 - smoothstep(0.0, 0.03, r);

    return 0.5 * decay * (wave*(1.0-core) + 0.35*core);
}

vec2 rippleDisplace(vec2 p, float t)
{
    vec2 c = mouseUV();
    vec2 d = p - c;
    float r = length(d) + 1e-6;
    vec2 dir = d / r;

    float h = rippleHeight(p, t);
    float eps = 0.002;
    float h2 = rippleHeight(p + dir*eps, t);
    float dh = (h2 - h) / eps;

    return -0.018 * dh * dir;
}

float potential(vec2 p, float t)
{
    p += rippleDisplace(p, t);

    vec2 w = p + 0.25 * vec2(
        sin(0.7*p.y + 0.8*t) + sin(1.3*p.x - 0.6*t),
        sin(0.9*p.x + 0.5*t) - sin(1.1*p.y - 0.7*t)
    );

    float ph = 0.35 * TAU * fbm(1.2*w + 0.25*t);

    float s1 = sin(TAU*(1.6*w.x + 0.17*w.y) + 1.1*t + ph);
    float s2 = sin(TAU*(2.3*w.y - 0.13*w.x) - 0.9*t - ph);

    return (s1 + 0.8*s2) + 2.4*rippleHeight(p,t);
}

vec2 efield(vec2 p, float t)
{
    float e = 0.002;
    float px1 = potential(p + vec2(e,0), t);
    float px0 = potential(p - vec2(e,0), t);
    float py1 = potential(p + vec2(0,e), t);
    float py0 = potential(p - vec2(0,e), t);
    return -vec2(px1 - px0, py1 - py0)/(2.0*e);
}

vec3 paletteA(float t)
{
    return vec3(0.5) + vec3(0.5)*cos(TAU*(vec3(1.0)*t + vec3(0.0,0.33,0.67)));
}

vec3 paletteB(float t)
{
    return vec3(0.5) + vec3(0.5)*cos(TAU*(vec3(1.0)*t + vec3(0.5,0.1,0.25)));
}

vec3 diffusionLayer(vec2 uv, float t)
{
    vec2 flow = efield(uv, t);
    float energy = length(flow);

    float d  = fbm(uv*2.5 + 0.3*flow + 0.2*t);
    float d2 = fbm(uv*4.0 - 0.4*flow - 0.1*t);

    float reaction = sin(6.0*d + 3.0*d2 + 0.6*t);
    float fieldPhase = potential(uv, t);

    float phaseSwitch = step(0.0, sin(fieldPhase*2.0 + 0.4*t));

    vec3 colA = paletteA(0.3*fieldPhase + 0.5*reaction + 0.2*energy);
    vec3 colB = paletteB(0.3*fieldPhase - 0.5*reaction + 0.2*energy);

    vec3 col = mix(colA, colB, phaseSwitch);

    float glow = smoothstep(0.05, 0.5, energy);
    col *= 0.6 + 1.4*glow;

    return col;
}

vec3 blurredField(vec2 uv, float t)
{
    float px = 1.0 / iResolution.y;
    vec2 o = vec2(px);

    vec3 col = vec3(0.0);

    col += diffusionLayer(uv + vec2(-o.x,-o.y), t) * 1.0;
    col += diffusionLayer(uv + vec2( 0.0,-o.y), t) * 2.0;
    col += diffusionLayer(uv + vec2( o.x,-o.y), t) * 1.0;

    col += diffusionLayer(uv + vec2(-o.x, 0.0), t) * 2.0;
    col += diffusionLayer(uv, t)                   * 4.0;
    col += diffusionLayer(uv + vec2( o.x, 0.0), t) * 2.0;

    col += diffusionLayer(uv + vec2(-o.x, o.y), t) * 1.0;
    col += diffusionLayer(uv + vec2( 0.0, o.y), t) * 2.0;
    col += diffusionLayer(uv + vec2( o.x, o.y), t) * 1.0;

    return col / 16.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5*iResolution.xy) / iResolution.y;
    float t = iTime;

    uv = rot(uv, 0.1*sin(0.2*t));

    vec2 uvd = uv + 0.9 * rippleDisplace(uv, t);

    vec3 col = blurredField(uvd * 10.0, t);

    col = 1.0 - exp(-1.2*col);

    float vign = smoothstep(1.4, 0.2, length(uv));
    col *= 0.5 + 0.7*vign;

    fragColor = vec4(col,1.0);
}
