#define PI 3.14159265

float hash(vec3 p){
    return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453);
}

float noise(vec3 p){
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f*f*(3.0-2.0*f);

    float n000 = hash(i + vec3(0,0,0));
    float n100 = hash(i + vec3(1,0,0));
    float n010 = hash(i + vec3(0,1,0));
    float n110 = hash(i + vec3(1,1,0));
    float n001 = hash(i + vec3(0,0,1));
    float n101 = hash(i + vec3(1,0,1));
    float n011 = hash(i + vec3(0,1,1));
    float n111 = hash(i + vec3(1,1,1));

    float n00 = mix(n000,n100,f.x);
    float n01 = mix(n001,n101,f.x);
    float n10 = mix(n010,n110,f.x);
    float n11 = mix(n011,n111,f.x);

    float n0 = mix(n00,n10,f.y);
    float n1 = mix(n01,n11,f.y);

    return mix(n0,n1,f.z);
}

float fbm(vec3 p){
    float v = 0.0;
    float a = 0.5;
    for(int i=0;i<6;i++){
        v += a * noise(p);
        p *= 2.2;
        a *= 0.5;
    }
    return v;
}

float pattern(vec3 p){
    float t = iTime * 0.15;

    vec3 q = vec3(
        fbm(p + t),
        fbm(p + vec3(5.2,1.3,2.7)),
        fbm(p + vec3(8.3,2.8,4.1))
    );

    vec3 r = vec3(
        fbm(p + 4.0*q),
        fbm(p + 4.0*q + 2.5),
        fbm(p + 4.0*q + 5.0)
    );

    return fbm(p + 4.0*r);
}

vec3 neonPalette(float t){
    vec3 deep    = vec3(0.04,0.01,0.10);
    vec3 violet  = vec3(0.55,0.0,1.0);
    vec3 magenta = vec3(1.0,0.0,0.85);
    vec3 cyan    = vec3(0.0,1.0,1.0);

    vec3 col = mix(deep, violet, smoothstep(0.1,0.5,t));
    col = mix(col, magenta, smoothstep(0.4,0.8,t));
    col += cyan * pow(t,4.0) * 0.7;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5*iResolution.xy)/iResolution.y;

    vec3 ro = vec3(0.0,0.0,5.2);
    vec3 rd = normalize(vec3(uv,-2.4));

    float radius = 1.0;
    float b = dot(ro,rd);
    float c = dot(ro,ro)-radius*radius;
    float h = b*b-c;

    vec3 bg = mix(vec3(0.01,0.0,0.05),
                  vec3(0.02,0.0,0.08),
                  length(uv)*1.6);

    bg += vec3(0.4,0.0,0.6) * fbm(vec3(uv*3.0,0.0)) * 0.04;

    if(h < 0.0){
        float vign = smoothstep(1.5,0.2,length(uv));
        fragColor = vec4(bg*vign,1.0);
        return;
    }

    float t = -b - sqrt(h);
    vec3 pos = ro + rd*t;
    vec3 n = normalize(pos);

    float rot = iTime * 0.18;
    mat2 R = mat2(cos(rot),-sin(rot),
                  sin(rot), cos(rot));
    n.xz = R * n.xz;

    float f = pattern(n * 4.8);
    float micro = fbm(n * 14.0) * 0.2;
    f += micro;

    f = pow(f,1.35);

    vec3 baseColor = neonPalette(f);

    float fresnel = pow(1.0 - max(dot(n,-rd),0.0), 4.0);
    float emission = pow(f,3.0);

    vec3 color =
        baseColor * 0.8
        + fresnel * vec3(0.0,1.0,1.0) * 1.3
        + emission * vec3(0.8,0.0,1.0) * 0.5;

    float halo = smoothstep(1.05,0.95,length(pos));
    color += halo * vec3(0.3,0.0,1.0)*0.6;

    float vignette = smoothstep(1.5,0.3,length(uv));
    color *= vignette;

    color = pow(color, vec3(0.85));

    fragColor = vec4(color,1.0);
}
