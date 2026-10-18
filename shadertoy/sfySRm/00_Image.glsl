const float PHI = 1.61803398875;
const float K   = 2.6;            

// amplitude of wave i as the slider s sweeps from 0to 1
float ampOf(int i, float s){
    float a = 0.10 + 0.12 * float(i);
    return smoothstep(a, a + 0.18, s);
}

vec4 crystal(vec3 p, float t, float s){
    vec3 d[6];
    d[0] = normalize(vec3( 1.0,  PHI,  0.0));
    d[1] = normalize(vec3( 1.0, -PHI,  0.0));
    d[2] = normalize(vec3( 0.0,  1.0,  PHI));
    d[3] = normalize(vec3( 0.0,  1.0, -PHI));
    d[4] = normalize(vec3( PHI,  0.0,  1.0));
    d[5] = normalize(vec3(-PHI,  0.0,  1.0));
    float raw = 0.0, A = 0.0;
    vec3  g = vec3(0.0);
    for(int i = 0; i < 6; i++){
        float amp = ampOf(i, s);
        float ph  = dot(p, d[i]) * K + t * (0.35 + 0.11 * float(i));
        raw += amp * cos(ph);
        g   -= amp * d[i] * K * sin(ph);
        A   += amp;
    }
    float inv = 1.0 / max(A, 1.0);
    return vec4(g, raw) * inv;
}

mat2 rot(float a){ float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q  = fragCoord / iResolution.xy;
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    float t = iTime * 0.5;

    // ---------- sliders ----------
    float x0 = 0.06, x1 = 0.94, sy = 0.075;
    float s;
    if(length(iMouse.xy) < 1.0){
        s = 0.5 - 0.5 * cos(iTime * 0.12);
    } else {
        s = clamp((iMouse.x / iResolution.x - x0) / (x1 - x0), 0.0, 1.0);
    }

    // ---------- stage zero ----------
    vec3 bg = 0.5 + 0.5 * cos(iTime + q.xyx + vec3(0.0, 2.0, 4.0));

    // ---------- crystal meth shit ----------
    vec3 ro = vec3(0.0, 0.0, t * 0.9);
    vec3 rd = normalize(vec3(uv, 1.5));
    rd.yz *= rot(0.10 * sin(t * 0.31));
    rd.xz *= rot(t * 0.05);
    rd.xy *= rot(0.12 * sin(t * 0.21));

    float starGate = smoothstep(0.60, 0.85, s); 
                                                 
    vec3  col = vec3(0.0);
    float tr  = 1.0;
    float tt  = 0.4 + 0.15 * fract(sin(dot(fragCoord, vec2(12.9898, 78.233))) * 43758.5453);

    for(int i = 0; i < 96; i++){
        vec3 p  = ro + rd * tt;
        vec4 fq = crystal(p, t, s);
        float f = fq.w;
        vec3  g = fq.xyz;

        float shell = abs(abs(f) - 0.45);
        float den   = exp(-shell * shell * 250.0);
        float star  = exp(-dot(g, g) * 30.0)
                    * (0.6 + 0.4 * sin(t * 3.0 + f * 20.0)) * starGate;

        if(den + star > 0.002){
            vec3 n = g / (length(g) + 1e-4);
            float fres = 1.0 - abs(dot(n, rd));
            vec3 irid  = 0.5 + 0.5 * cos(6.28318 * (fres * 1.2 + f * 0.7 + vec3(0.00, 0.33, 0.66)));
            vec3 tint  = mix(vec3(0.20, 0.55, 1.00), vec3(1.00, 0.45, 0.15), smoothstep(-0.6, 0.6, f));
            vec3 emit  = irid * tint * den * 0.16
                       + vec3(1.0, 0.9, 0.7) * star * 0.25;
            emit *= exp(-tt * 0.10);
            col  += tr * emit;
            tr   *= 1.0 - den * 0.045;
        }
        if(tr < 0.02) break;
        tt += 0.11 + tt * 0.012;
    }

    col = 1.0 - exp(-col * 2.2);
    col = pow(col, vec3(0.85));

    // ---------- interpolate gradient -> crystal ----------
    float blend = smoothstep(0.02, 0.40, s);
    col  = mix(bg, col, blend);
    col *= 1.0 - 0.25 * dot(uv, uv) * blend;

    // ---------- schlidurr ----------
    vec2 px = fragCoord;
    vec2 a  = vec2(x0, sy) * iResolution.xy;
    vec2 b  = vec2(x1, sy) * iResolution.xy;
    vec2 pa = px - a, ba = b - a;
    float h      = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dTrack = length(pa - ba * h);
    float track  = smoothstep(1.5, 0.0, dTrack - 2.0);
    float fill   = step(h, s);

    float ticks = 0.0;
    for(int i = 0; i < 6; i++){
        float ts = 0.19 + 0.12 * float(i); 
        float dt = length(px - mix(a, b, ts));
        ticks = max(ticks, smoothstep(4.0, 1.0, dt) * (0.30 + 0.70 * ampOf(i, s)));
    }

    vec2  kp   = mix(a, b, s);
    float dk   = length(px - kp);
    float knob = smoothstep(7.0, 5.0, dk);
    float halo = exp(-dk * dk / 220.0) * 0.35;

    col  = mix(col, vec3(0.9), track * (0.22 + 0.5 * fill));
    col  = mix(col, vec3(1.0, 0.85, 0.55), ticks * 0.9);
    col += vec3(0.6, 0.8, 1.0) * halo;
    col  = mix(col, vec3(1.0), knob);

    fragColor = vec4(col, 1.0);
}