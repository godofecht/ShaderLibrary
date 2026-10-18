#define INTENSITY 1.35
#define BASE_DARKEN 0.82
#define BLOOM 0.65

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    vec3 base = texture(iChannel1, uv).rgb;

    vec3 diff = texture(iChannel0, uv).rgb;

    vec3 bloom = vec3(0.0);
    bloom += texture(iChannel0, uv + vec2( 1.5,  0.0) * px).rgb;
    bloom += texture(iChannel0, uv + vec2(-1.5,  0.0) * px).rgb;
    bloom += texture(iChannel0, uv + vec2( 0.0,  1.5) * px).rgb;
    bloom += texture(iChannel0, uv + vec2( 0.0, -1.5) * px).rgb;
    bloom *= 0.25;

    vec3 glow = (diff + bloom * BLOOM) * COLOR * INTENSITY;

    vec3 col = base * BASE_DARKEN + glow;

    col = 1.0 - exp(-col);
    col = pow(col, vec3(0.92));

    fragColor = vec4(col, 1.0);
}