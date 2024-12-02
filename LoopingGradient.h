uniform vec2 resolution;
uniform float time;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    fragColor = vec4(uv, 0.5 + 0.5 * sin(time), 1.0);
}
