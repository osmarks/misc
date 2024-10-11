float lscale = 0.1;
float lscaleh = 0.05;

float dfn(float x) {
    return abs(mod(x - lscaleh, lscale) - lscaleh) / lscale;
}

float dfn_nonlin(float x) {
    //return x;
    if (x < 0.1) return 0.3;
    else return 0.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // -1 to 1 ish maybe
    vec2 uv = 2.0*fragCoord/iResolution.xx - vec2(1.0,1.0);
    
    vec3 ldir = vec3(1.0, uv);
    vec3 l0 = vec3(0.0);
    
    float n = 1.0;
    vec3 bri = vec3(0.0);
    
    for (float n = 1.0; n <= 3.0; n += 1.0) {
        vec3 p0 = vec3(n, 0.0, 0.0);
        float lam = (p0 - l0).x / ldir.x;
        vec3 isect = l0 + ldir * lam;
        //vec3 isect = vec3(0.0, uv);
        bri += vec3(0.0, dfn_nonlin(dfn(isect.y)) + dfn_nonlin(dfn(isect.z)), 0.0);
    }

    // Output to screen
    fragColor = vec4(bri,1.0);
}
