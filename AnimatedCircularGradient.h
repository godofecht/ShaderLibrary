uniform vec2 resolution;
uniform float time;

void main() 
{
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    vec2 center = uv - 0.5;
    float radius = length(center) * 2.0;
    gl_FragColor = vec4(radius, 0.5 - radius, abs(sin(time)), 1.0);
}
