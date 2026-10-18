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


void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 res = iResolution.xy;
    float ar = res.x/res.y;

    vec2 uv = (fragCoord - 0.5*res)/res.y;

    // mouse normalized -1..1
    vec2 m = (iMouse.xy/res - 0.5);
    m.x *= ar;

    float down = step(0.5, iMouse.z);

    float warp  = mix(0.0, 1.5, clamp(m.x*0.5+0.5,0.0,1.0));
    float bend  = mix(-4.0, 4.0, clamp(m.y*0.5+0.5,0.0,1.0));

    vec2 p = uv;

    vec2 d = p - m;
    float r = length(d);
    float ang = atan(d.y, d.x);
    ang += bend * exp(-5.0*r);
    p = m + r*vec2(cos(ang), sin(ang));

    p += warp * vec2(
        fbm(p*3.0 + vec2(0.0,iTime*0.3)),
        fbm(p*3.0 + vec2(5.2,iTime*0.3))
    );

    float thickness = 0.01;
    float wire = thickness / abs(p.y);

    float cross = 0.0;
    cross += 0.002/abs(uv.x-m.x);
    cross += 0.002/abs(uv.y-m.y);

    float frame = smoothstep(0.48,0.49,max(abs(uv.x/ar),abs(uv.y)));

    float ink = wire;
    ink = max(ink, cross*0.6);
    ink = max(ink, frame*2.0);

    if(down>0.5){
        ink *= 1.5;
    }

    ink = clamp(ink,0.0,1.0);

    vec3 col = vec3(1.0 - ink);

    fragColor = vec4(col,1.0);
}
