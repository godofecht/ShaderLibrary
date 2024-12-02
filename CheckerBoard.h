uniform vec2 resolution;
uniform float time;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution.xy * 10.0;
    float checker = mod(floor(uv.x) + floor(uv.y) + floor(time), 2.0);
    gl_FragColor = vec4(vec3(checker), 1.0);
}
