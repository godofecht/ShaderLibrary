uniform vec2 resolution;
uniform float time;

void main() 
{
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    vec2 center = uv - 0.5;
    float angle = atan(center.y, center.x) + time;
    float radius = length(center);
    float spiral = sin(angle * 10.0 - radius * 20.0) * 0.5 + 0.5;
    gl_FragColor = vec4(vec3(spiral), 1.0);
}
