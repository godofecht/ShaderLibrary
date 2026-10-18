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

bool raySphere(in vec3 ro, in vec3 rd, float r, out float tHit)
{
    // Solve |ro + t*rd|^2 = r^2
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r*r;
    float h = b*b - c;
    if(h < 0.0) return false;
    h = sqrt(h);

    float t0 = -b - h;
    float t1 = -b + h;
    tHit = (t0 > 0.0) ? t0 : t1;
    return tHit > 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    float bass   = audioLow();
    float treble = audioHigh();
    float t = iTime * (1.2 + 2.5*bass);

    // Camera + ray
    vec3 ro = vec3(0.0, 0.0, 2.6);
    vec3 rd = normalize(vec3(p, -1.5));

    // Sphere intersection
    float th;
    if(!raySphere(ro, rd, 1.0, th))
    {
        fragColor = vec4(0.0,0.0,0.0,1.0);
        return;
    }

    vec3 pos = ro + th * rd;
    vec3 nrm = normalize(pos);

    // Lat-long coords (stable, seam at -pi/pi)
    float lon = atan(nrm.z, nrm.x);        // [-pi, pi]
    float lat = asin(clamp(nrm.y,-1.0,1.0)); // [-pi/2, pi/2]
    vec2 suv = vec2(lon/TAU + 0.5, lat/3.14159265359 + 0.5);

    // Build a 2D domain from sphere coords; wrap longitude seamlessly
    // Use lon as unwrapped coordinate so flow doesn't "stick" at the seam.
    vec2 dom = vec2(lon, lat);

    // Scale domain to taste
    dom *= 1.35;

    // Spherical “mask” based on view angle (rim darkening + center emphasis)
    float ndv = clamp(dot(nrm, -rd), 0.0, 1.0);
    float mask = pow(ndv, 1.4);

    // Flow warp in domain space
    vec2 q = dom;
    q += 0.40 * mask * curlField(q*2.0, t);
    q += 0.20 * mask * gradField(q*2.5, t);
    q += 0.15 * mask * curlField(q*3.5, t + 1.0);

    float energy = length(q);
    float nn = fbm(q*4.0 + t);

    // Phase tied to spherical coords (use lon/lat to keep it “wrapped” to surface)
    float phase = sin(TAU*(0.65*q.x + 0.85*q.y) + 3.0*nn + t);

    vec3 col = palette(0.4*phase + 0.7*nn + 0.5*energy + 0.4*t);

    // Lighting for sphere presence
    vec3 lightDir = normalize(vec3(-0.4, 0.6, 0.7));
    float diff = clamp(dot(nrm, lightDir), 0.0, 1.0);
    float spec = pow(clamp(dot(reflect(-lightDir, nrm), -rd), 0.0, 1.0), 48.0);

    col *= (0.35 + 0.95*diff);
    col += 0.25*spec;

    // Audio shaping
    col *= 1.5 + 3.5*bass;
    col = pow(col, vec3(max(0.12, 0.8 - 0.5*treble)));
    col = 1.0 - exp(-col);

    // Rim + vignette around the sphere silhouette
    float rim = pow(1.0 - ndv, 2.2);
    col *= 0.85 + 0.55*(1.0 - rim);

    fragColor = vec4(col, 1.0);
}
