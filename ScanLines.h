uniform vec2 resolution;
uniform float time;

void main() 
{
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    float bar = smoothstep(0.4, 0.6, abs(sin(time + uv.y * 10.0)));
    gl_FragColor = vec4(uv.x, uv.y, bar, 1.0);
}
