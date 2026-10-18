#define AA 1
#define ZERO min(iFrame,0)

float sdBox( in vec3 p, in vec3 b )
{
    vec3 q = abs(p) - b;
    float g = max(q.x, max(q.y, q.z));
    return g < 0.0 ? g : length(max(q, 0.0));
}

float hash( in vec3 p )
{
    p += 1000.0;
    return fract(123.0 * sin(p.x * 21.6) * sin(p.y * 43.4) * sin(p.z * 14.5));
}

float cnoise( in vec3 p )
{
    vec3 ip = floor(p);
    vec3 fp = fract(p);

    fp = fp * fp * (3.0 - 2.0 * fp);

    float a = hash(ip + vec3(0, 0, 0));
    float b = hash(ip + vec3(1, 0, 0));
    float c = hash(ip + vec3(0, 1, 0));
    float d = hash(ip + vec3(1, 1, 0));
    float e = hash(ip + vec3(0, 0, 1));
    float f = hash(ip + vec3(1, 0, 1));
    float g = hash(ip + vec3(0, 1, 1));
    float h = hash(ip + vec3(1, 1, 1));

    return mix(
        mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y),
        mix(mix(e, f, fp.x), mix(g, h, fp.x), fp.y),
        fp.z
    );
}

float fbm( in vec3 p )
{
    float f = 0.0;
    float a = 0.5;

    for( int i = 0; i < 6; i++ )
    {
        f += a * cnoise(p);
        p = p.yxz * 1.99 + 0.1;
        a *= 0.56;
    }

    return f;
}

float sdPyramid( in vec3 p, in float h, in float b )
{
    float k = b / h;
    float inv = inversesqrt(1.0 + k * k);

    float dx = (abs(p.x) + k * p.y - b) * inv;
    float dz = (abs(p.z) + k * p.y - b) * inv;
    float db = -p.y;

    return max(max(dx, dz), db);
}

vec4 pyramidBricks( in vec3 p, in float h, in float b )
{
    float k = b / h;
    float inv = inversesqrt(1.0 + k * k);

    float sx = (abs(p.x) + k * p.y - b) * inv;
    float sz = (abs(p.z) + k * p.y - b) * inv;

    float useXFace = step(sz, sx);

    float u = mix(p.x, p.z, useXFace);
    float v = clamp(p.y, 0.0, h);

    float brickH = 0.135;
    float brickW = mix(0.31, 0.14, v / h);

    float row = floor(v / brickH);
    float uu = u + 0.5 * brickW * mod(row, 2.0);

    float cx = floor(uu / brickW);
    float cy = row;

    float fx = fract(uu / brickW);
    float fy = fract(v / brickH);

    float dx = (0.5 - abs(fx - 0.5)) * brickW;
    float dy = (0.5 - abs(fy - 0.5)) * brickH;

    float line = min(dx, dy);
    float mortar = 1.0 - smoothstep(0.010, 0.026, line);

    float rnd = hash(vec3(cx, cy, useXFace * 13.7 + step(0.0, u) * 3.1));

    return vec4(mortar, rnd, useXFace, 0.0);
}

vec4 map( in vec3 p )
{
    vec3 op = p;

    float an = 6.2831853 * iTime / 44.0;
    float co = cos(an);
    float si = sin(an);

    vec3 q = p;
    q.xz = mat2(co, -si, si, co) * q.xz;

    q.y += 1.20;

    float pyrH = 2.70;
    float pyrB = 1.75;

    vec4 br = pyramidBricks(q, pyrH, pyrB);

    float f = fbm(q / 0.14);

    float dPyr = sdPyramid(q, pyrH, pyrB);
    dPyr -= 0.015;
    dPyr += 0.026 * br.x;
    dPyr += 0.020 * (f - 0.45);

    float floorNoise = fbm(vec3(op.x * 2.0, 0.0, op.z * 2.0));
    float dFloor = op.y + 1.22 + 0.012 * (floorNoise - 0.5);

    if( dFloor < dPyr )
    {
        return vec4(dFloor, 0.0, floorNoise, 1.0);
    }

    return vec4(dPyr, br.x, br.y, 0.0);
}

vec3 calcNormal( in vec3 pos )
{
    vec3 n = vec3(0.0);

    for( int i = ZERO; i < 4; i++ )
    {
        vec3 e = 0.5773 * (2.0 * vec3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
        n += e * map(pos + 0.0025 * e).x;
    }

    return normalize(n);
}

float calcAO( in vec3 pos, in vec3 nor )
{
    float occ = 0.0;
    float sca = 1.0;

    for( int i = 0; i < 8; i++ )
    {
        float h = 0.005 + 0.22 * float(i) / 8.0;
        vec3 dir = normalize(nor + 0.85 * sin(h * 31.31 + vec3(0, 2, 4)));
        dir *= sign(dot(dir, nor));

        float d = map(pos + h * dir).x;

        occ += max(h - d, 0.0) * sca;
        sca *= 0.95;

        if( occ > 1.0 / 1.5 )
        {
            break;
        }
    }

    return clamp(1.0 - 1.5 * occ, 0.0, 1.0);
}

float calcSoftshadow( in vec3 ro, in vec3 rd, in float k )
{
    float res = 1.0;
    float t = 0.02;

    for( int i = 0; i < 128; i++ )
    {
        float h = map(ro + rd * t).x;

        res = min(res, k * h / t);
        t += clamp(h * 0.55, 0.015, 0.22);

        if( res < 0.01 || t > 8.0 )
        {
            break;
        }
    }

    return clamp(res, 0.0, 1.0);
}

vec4 intersect( in vec3 ro, in vec3 rd )
{
    vec4 res = vec4(-1.0);

    float t = 0.001;
    float tmax = 12.0;

    for( int i = 0; i < 320 && t < tmax; i++ )
    {
        vec4 h = map(ro + rd * t);

        if( h.x < 0.0015 )
        {
            res = vec4(t, h.yzw);
            break;
        }

        t += max(h.x * 0.48, 0.003);
    }

    return res;
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = cross(cu, cw);

    return mat3(cu, cv, cw);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);

#if AA > 1
    for( int m = ZERO; m < AA; m++ )
    for( int n = ZERO; n < AA; n++ )
    {
        vec2 o = vec2(float(m), float(n)) / float(AA) - 0.5;
        vec2 p = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
#else
        vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
#endif

        vec3 ta = vec3(0.0, -0.10, 0.0);
        vec3 ro = vec3(4.2, 1.20, 3.4);

        mat3 ca = setCamera(ro, ta, 0.0);

        float fl = 2.0;
        vec3 rd = ca * normalize(vec3(p, fl));

        vec3 col = vec3(1.0 + rd.y) * 0.028;
        col += vec3(0.015, 0.022, 0.035);

        vec4 hit = intersect(ro, rd);

        if( hit.x > 0.0 )
        {
            vec3 pos = ro + hit.x * rd;
            vec3 nor = calcNormal(pos);

            vec3 mate;

            if( hit.w > 0.5 )
            {
                mate = vec3(0.075, 0.068, 0.058);
                mate *= 0.75 + 0.45 * hit.z;
            }
            else
            {
                vec3 brickColor = vec3(0.22, 0.055, 0.018);
                brickColor *= 0.75 + 0.55 * hit.z;
                brickColor *= 1.0 + 0.16 * sin(3.1415927 * hit.z + vec3(0, 2, 4));

                vec3 mortarColor = vec3(0.19, 0.145, 0.115);

                mate = mix(brickColor, mortarColor, hit.y);
            }

            vec3 lig = normalize(vec3(0.45, 0.65, -0.75));
            float dif = max(0.0, dot(nor, lig));
            float sha = calcSoftshadow(pos + nor * 0.004, lig, 30.0);

            vec3 hal = normalize(lig - rd);
            float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 12.0);
            spe *= dif * sha;
            spe *= 0.04 + 0.96 * pow(clamp(1.0 - dot(hal, lig), 0.0, 1.0), 5.0);

            float occ = calcAO(pos, nor);

            vec3 warm = vec3(4.2, 2.35, 1.15);
            vec3 cool = vec3(0.42, 0.60, 1.45);

            col = mate * dif * sha * warm;
            col += mate * occ * cool * 0.95;
            col += spe * vec3(4.0);

            float rim = pow(clamp(1.0 + dot(nor, rd), 0.0, 1.0), 3.0);
            col += rim * vec3(0.25, 0.35, 0.55) * 0.45;

            float fog = exp(-0.030 * hit.x * hit.x);
            vec3 bg = vec3(0.012, 0.016, 0.022) + vec3(1.0 + rd.y) * 0.03;
            col = mix(bg, col, fog);
        }

        col = col * 2.5 / (2.0 + col);
        tot += pow(col, vec3(0.45));

#if AA > 1
    }

    tot /= float(AA * AA);
#endif

    tot += sin(fragCoord.x * 114.0) * sin(fragCoord.y * 211.1) / 512.0;

    fragColor = vec4(tot, 1.0);
}
