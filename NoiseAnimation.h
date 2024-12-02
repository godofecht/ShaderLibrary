uniform vec2 resolution;
uniform float time;

float noise(vec2 p) 
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() 
{
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    vec2 p = uv * 10.0 + vec2(time * 0.1);
    float n = noise(p);
    gl_FragColor = vec4(vec3(n), 1.0);
}
