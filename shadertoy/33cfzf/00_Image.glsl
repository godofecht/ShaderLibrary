// -------------------------------------------
// Domain Warped FBM – Shadertoy Version
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    // Aspect-corrected coordinates
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) /
              min(iResolution.x, iResolution.y);

    // Mouse interaction (only when pressed)
    vec2 m = iMouse.xy / iResolution.xy;
    if (iMouse.z > 0.0) {
        uv += (m - 0.5) * 0.5;
    }

    uv *= 3.0;

    vec2 q, r;
    float f = pattern(uv, q, r);

    vec3 color = vec3(0.1, 0.15, 0.2);

    color = mix(color, vec3(0.2, 0.4, 0.6),
                clamp((f * f) * 4.0, 0.0, 1.0));

    color = mix(color, vec3(0.6, 0.1, 0.3),
                clamp(length(q), 0.0, 1.0));

    color = mix(color, vec3(0.8, 0.9, 0.2),
                clamp(abs(r.x), 0.0, 1.0));

    float intensity = f * f * f + 0.6 * f * f + 0.5 * f;

    vec3 finalColor = color * intensity;

    // Vignette
    vec2 vUv = fragCoord / iResolution.xy;
    finalColor *= 0.5 +
                  0.5 * pow(16.0 *
                  vUv.x * vUv.y *
                  (1.0 - vUv.x) *
                  (1.0 - vUv.y), 0.1);

    fragColor = vec4(finalColor, 1.0);
}
