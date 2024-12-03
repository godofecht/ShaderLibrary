#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader (float2 fragCoord [[position]], constant float2 &resolution [[buffer(0)]], constant float &time [[buffer(1)]])
{
    float2 uv = fragCoord / resolution;
    float2 center = uv - float2 (0.5, 0.5);
    float radius = length (center) * 2.0;
    return float4 (radius, 0.5 - radius, abs (sin (time)), 1.0);
}
