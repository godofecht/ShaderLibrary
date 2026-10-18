// ShaderToy version

// ---- User Controls (edit manually in ShaderToy) ----
float uScale      = 8.0;
float uSpeed      = 0.4;
float uComplexity = 5.0;
float uBrightness = 0.4;
float uRippleStr  = 0.3;
float uRefraction = 0.15;

// Improved hash
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123) * 2.0 - 1.0;
}

// Perlin noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
        mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// Ridged FBM
float ridgedFBM(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    for (int i = 0; i < 6; i++) {
        if (float(i) >= uComplexity) break;
        float n = abs(noise(p * freq));
        v += (1.0 - n) * amp;
        freq *= 2.0;
        amp *= 0.5;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy)
              / min(iResolution.x, iResolution.y);

    // Mouse handling (ShaderToy: iMouse.xy = pixels, z>0 when pressed)
    vec2 mPos = iMouse.xy;
    if (iMouse.z <= 0.0) {
        mPos = 0.5 * iResolution.xy; // center if not pressed
    }

    vec2 mouse = (mPos - 0.5 * iResolution.xy)
                 / min(iResolution.x, iResolution.y);

    float dist = length(uv - mouse);
    float ripplePadding = 0.7;
    float rippleMask = smoothstep(ripplePadding, 0.0, dist);

    float waves = sin(dist * 30.0 - iTime * 6.0) * 0.5 + 0.5;
    waves += sin(dist * 15.0 - iTime * 3.0) * 0.3;
    float rippleDisp = waves * rippleMask * uRippleStr;

    vec2 rippleDir = normalize(uv - mouse + 1e-4);
    vec2 refractedUV = uv + rippleDir * rippleDisp * uRefraction;

    float t = iTime * uSpeed;

    float n1 = ridgedFBM(
        refractedUV * uScale + vec2(t * 0.5, t * 0.3)
    );

    float n2 = ridgedFBM(
        refractedUV * uScale
        - vec2(t * 0.2, -t * 0.4)
        + n1 * 0.2
    );

    float waterSurface = n1 * n2;

    vec3 deepColor    = vec3(0.01, 0.1, 0.2);
    vec3 shallowColor = vec3(0.1, 0.5, 0.7);
    vec3 crestColor   = vec3(0.8, 0.95, 1.0);

    vec3 col = mix(deepColor, shallowColor, waterSurface);

    float crests = pow(waterSurface, 3.0) * 1.5;
    col += crests * crestColor;

    float rippleGlint = 0.0;
    if (uRippleStr > 0.0) {
        rippleGlint =
            smoothstep(0.7, 1.0, rippleDisp / uRippleStr)
            * rippleMask;
    }

    col += rippleGlint * 0.4 * crestColor;
    col *= (1.2 - length(uv) * 0.5) * uBrightness;

    fragColor = vec4(col, 1.0);
}
