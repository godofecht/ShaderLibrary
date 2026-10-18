#define pi 3.14159265359
#define oz vec2(1.0,0.0)

float hash12(vec2 p){
    vec3 p3 = fract(vec3(p.xyx)*.1031);
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.x+p3.y)*p3.z);
}

vec2 randVec(vec2 p){
    float a = hash12(p)*2.0*pi;
    return vec2(cos(a), sin(a));
}

float perlin(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 s = f*f*(3.0-2.0*f);

    float a = dot(randVec(i), f);
    float b = dot(randVec(i+oz.xy), f-oz.xy);
    float c = dot(randVec(i+oz.yx), f-oz.yx);
    float d = dot(randVec(i+oz.xx), f-oz.xx);

    return mix(mix(a,b,s.x), mix(c,d,s.x), s.y);
}

float fbm(vec2 p){
    float r = 0.0;
    float a = 0.5;
    for(int i=0;i<6;i++){
        r += a*perlin(p);
        p *= 2.0;
        a *= 0.5;
    }
    return r;
}

bool intersectSphere(vec3 ro, vec3 rd, float radius, out float t){
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius*radius;
    float h = b*b - c;
    if(h < 0.0) return false;
    h = sqrt(h);
    t = -b - h;
    if(t < 0.0) t = -b + h;
    return t > 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 res = iResolution.xy;
    float ar = res.x/res.y;

    vec2 uv = (fragCoord - 0.5*res)/res.y;

    vec3 ro = vec3(0.0, 0.0, 2.5);
    vec3 rd = normalize(vec3(uv, -1.5));

    float t;
    if(!intersectSphere(ro, rd, 1.0, t)){
        fragColor = vec4(1.0);
        return;
    }

    vec3 pos = ro + rd*t;
    vec3 normal = normalize(pos);

    float theta = atan(normal.z, normal.x);
    float phi   = acos(clamp(normal.y, -1.0, 1.0));

    vec2 suv;
    suv.x = theta/pi;
    suv.y = phi/pi - 0.5;

    vec2 m = (iMouse.xy/res - 0.5);
    m.x *= ar;

    float down = step(0.5, iMouse.z);

    float mx = clamp(m.x*0.5+0.5, 0.0, 1.0);
    float my = clamp(m.y*0.5+0.5, 0.0, 1.0);

    float bend = mix(-4.0, 4.0, my);

    float freq = mix(1.0, 12.0, mx);
    float thickness = mix(0.02, 0.002, mx);
    float rimPower = mix(2.0, 6.0, mx);

    vec2 p = suv;

    vec2 d = p - m;
    float r = length(d);
    float ang = atan(d.y, d.x);
    ang += bend * exp(-5.0*r);
    p = m + r*vec2(cos(ang), sin(ang));

    p += 1.5 * vec2(
        fbm(p*3.0 + vec2(0.0,iTime*0.3)),
        fbm(p*3.0 + vec2(5.2,iTime*0.3))
    );

    p.y += 0.1 * sin(p.x * freq * pi);

    float wire = thickness / abs(p.y);
    float ink = clamp(wire, 0.0, 1.0);

    if(down > 0.5){
        ink *= 1.5;
    }

    vec3 lightDir = normalize(vec3(0.5,0.8,0.6));
    float diff = clamp(dot(normal, lightDir), 0.0, 1.0);
    float rim  = pow(1.0 - max(dot(normal, -rd),0.0), rimPower);

    vec3 base = vec3(1.0 - ink);
    vec3 col = base * (0.3 + 0.7*diff) + rim*0.15;

    fragColor = vec4(col,1.0);
}