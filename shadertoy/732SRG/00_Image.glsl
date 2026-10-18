#define PI 3.14159
const float scale = 128.;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.yx - .5*iResolution.yx) / min(iResolution.x, iResolution.y);
    if (abs(uv.x) > .5 || abs(uv.y) > .5) return;
    float time = 2.*PI*(iTime/2.5);
    float total = 0.;
    for (float i = 0.; i < 7.; i++)
    {
        float angle = PI*float(i)/(10. + cos(sin(i)*3. * i)*3.);
        float len = dot(uv, vec2( cos(angle), sin(angle)));
        total += (cos(2.*scale*len + time)+1.)/2.;
    }
    vec3 color = vec3(1.-abs(2.*fract(.5*total)-1.));
    fragColor = vec4(color, 1.0);
}
