// -------------------------------------------
// Domain Warped FBM Sphere – Shadertoy Version
// -------------------------------------------

// Generic 2D random function
float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 2D Value Noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

// Fractional Brownian Motion
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Domain warping pattern
float pattern(vec2 p, out vec2 q, out vec2 r) {
    float t = iTime * 0.15;
    
    q.x = fbm(p + vec2(0.0) + 0.1 * t);
    q.y = fbm(p + vec2(5.2, 1.3) + 0.15 * t);

    r.x = fbm(p + 4.0 * q + vec2(1.7, 9.2) + 0.2 * t);
    r.y = fbm(p + 4.0 * q + vec2(8.3, 2.8) + 0.1 * t);

    return fbm(p + 4.0 * r);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalized screen coords
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Camera
    vec3 ro = vec3(0.0, 0.0, 3.0);
    vec3 rd = normalize(vec3(uv, -1.5));

    // Sphere (unit radius)
    float r = 1.0;
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r*r;
    float h = b*b - c;

    // Miss → black
    if (h < 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Closest hit
    float t = -b - sqrt(h);
    vec3 pos = ro + rd * t;
    vec3 n = normalize(pos);

    // Spherical coordinates
    float theta = atan(n.z, n.x);      // longitude
    float phi   = acos(n.y);           // latitude

    // Map to 2D domain
    vec2 sphUV = vec2(
        theta / (2.0 * 3.14159265),
        phi   / 3.14159265
    );

    sphUV *= 6.0; // pattern scale

    vec2 q, r2;
    float f = pattern(sphUV, q, r2);

    vec3 color = vec3(0.1, 0.15, 0.2);

    color = mix(color, vec3(0.2, 0.4, 0.6),
                clamp((f * f) * 4.0, 0.0, 1.0));

    color = mix(color, vec3(0.6, 0.1, 0.3),
                clamp(length(q), 0.0, 1.0));

    color = mix(color, vec3(0.8, 0.9, 0.2),
                clamp(abs(r2.x), 0.0, 1.0));

    float intensity = f*f*f + 0.6*f*f + 0.5*f;

    // Lighting (simple, stable)
    vec3 lightDir = normalize(vec3(0.4, 0.7, 0.6));
    float diff = clamp(dot(n, lightDir), 0.0, 1.0);

    vec3 finalColor = color * intensity * (0.25 + 0.75 * diff);

    fragColor = vec4(finalColor, 1.0);
}

