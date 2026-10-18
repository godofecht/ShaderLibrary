#define LAYERS 20
#define GRID_X 8.0
#define GRID_Y 4.0
#define MARGIN 0.92

// ------------------------------------------------------------

vec2 rot(vec2 p, float a){
    float s = sin(a);
    float c = cos(a);
    return vec2(p.x*c - p.y*s, p.x*s + p.y*c);
}

float sdSeg(vec2 p, vec2 a, vec2 b){
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa,ba)/max(dot(ba,ba),1e-8),0.0,1.0);
    return length(pa - ba*h);
}

bool inPoly(vec2 p, vec2 v[7]){
    bool c = false;
    for(int i=0,j=6;i<7;j=i,i++){
        vec2 a=v[i], b=v[j];
        bool m=((a.y>p.y)!=(b.y>p.y));
        float x=(b.x-a.x)*(p.y-a.y)/(b.y-a.y+1e-8)+a.x;
        if(m && p.x<x) c=!c;
    }
    return c;
}

float sdArrow(vec2 p, float L, float t, float hW, float hL){
    vec2 v[7];
    float x0=-0.5*L;
    float x1= 0.5*L;
    float x2= x1+hL;

    v[0]=vec2(x0,-t);
    v[1]=vec2(x1,-t);
    v[2]=vec2(x1,-hW);
    v[3]=vec2(x2,0.0);
    v[4]=vec2(x1,hW);
    v[5]=vec2(x1,t);
    v[6]=vec2(x0,t);

    float d=1e9;
    for(int i=0;i<7;i++)
        d=min(d, sdSeg(p, v[i], v[(i+1)%7]));

    return inPoly(p,v) ? -d : d;
}

// ------------------------------------------------------------
// Stable constrained motif

float motifInk(vec2 pCell, float AA, float t)
{
    const int L = 20;   // no macro dependency

    float phase = sin(t * 0.6);
    float u = 0.5 + 0.5 * phase;

    float baseThick = 0.0275 * mix(0.9, 1.15, u);
    float baseLen   = 0.46   * mix(0.92, 1.08, u);

    float stepDist  = 0.3422228 * mix(0.95, 1.05, u);

    float sizeShrink= mix(0.76, 0.82, u);
    float thinShrink= mix(0.80, 0.86, u);

    float twistAmt  = mix(0.12, 0.20, u);

    float headWMul  = mix(3.0, 3.6, u);
    float headLMul  = mix(5.0, 5.8, u);

    float ink = 0.0;

    for(int i = 0; i < L; i++)
    {
        float f = float(i);
        float s = pow(sizeShrink, f);

        float thick = baseThick * pow(thinShrink, f);
        float len   = baseLen   * s;
        float rad   = stepDist  * s;
        float crot  = f * twistAmt;

        float hW = thick * headWMul;
        float hL = thick * headLMul;

        vec2 p = rot(pCell, -crot);

        float d0 = sdArrow(p  + vec2(0.0, rad), len, thick, hW, hL);

        vec2 p1 = vec2(-p.y, p.x);
        float d1 = sdArrow(p1 + vec2(0.0, rad), len, thick, hW, hL);

        vec2 p2 = vec2(-p1.y, p1.x);
        float d2 = sdArrow(p2 + vec2(0.0, rad), len, thick, hW, hL);

        vec2 p3 = vec2(-p2.y, p2.x);
        float d3 = sdArrow(p3 + vec2(0.0, rad), len, thick, hW, hL);

        float a = max(
                    max(smoothstep(AA,-AA,d0), smoothstep(AA,-AA,d1)),
                    max(smoothstep(AA,-AA,d2), smoothstep(AA,-AA,d3))
                 );

        ink = max(ink, a);
    }

    return ink;
}


// ------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float t = iTime;

    float S  = 1.0 / min(iResolution.x, iResolution.y);
    float AA = S;

    vec2 uv = S * (fragCoord - 0.5*iResolution.xy);
    vec2 view = iResolution.xy * S;

    float TILE0 = 2.0 * 0.3422228;
    vec2 grid = vec2(GRID_X, GRID_Y);

    float scale = MARGIN * min(view.x / (grid.x * TILE0),
                               view.y / (grid.y * TILE0));

    vec2 uvm = uv / max(scale,1e-8);

    vec2 gridSize = grid * TILE0;
    vec2 origin   = -0.5 * gridSize;
    vec2 rel      = uvm - origin;
    vec2 baseCid  = floor(rel / TILE0);

    float ink = 0.0;

    for(int oy=-1; oy<=1; oy++){
        for(int ox=-1; ox<=1; ox++){

            vec2 cid = baseCid + vec2(float(ox), float(oy));

            if(cid.x < 0.0 || cid.y < 0.0 ||
               cid.x >= grid.x || cid.y >= grid.y)
                continue;

            vec2 cellCenter = origin + (cid + 0.5) * TILE0;
            vec2 pCell = uvm - cellCenter;

            if (mod(cid.x,2.0) > 0.5) pCell.x = -pCell.x;
            if (mod(cid.y,2.0) > 0.5) pCell.y = -pCell.y;

            ink = max(ink, motifInk(pCell, AA, t));
        }
    }

    vec3 bg = vec3(0.06,0.08,0.12);
    vec3 fg = vec3(0.75,0.85,1.0);

    vec3 col = mix(bg, fg, ink);

    fragColor = vec4(col,1.0);
}
