precision highp float;

varying vec2 vUV;

uniform int SEED;


float rnd(vec2 xy)
{
    return fract(sin(dot(xy, vec2(12.9898 - float(SEED) , 78.233 + float(SEED) )))* (43758.5453 + float(SEED) ));
}


const vec2 zOffset = vec2(37.0,17.0);
const vec2 wOffset = vec2(59.0,83.0);

vec4 makeHash(vec2 uv)
{
	float r = rnd( (uv+0.5)/256.0 );
	float g = rnd( (uv+0.5 + zOffset)/256.0 );
	float b = rnd( (uv+0.5 + wOffset)/256.0 );
	float a = rnd( (uv+0.5 + zOffset + wOffset)/256.0 );

	return vec4(r, g, b, a);
}


const uint k = 1103515245U;  // GLIB C
//const uint k = 134775813U;   // Delphi and Turbo Pascal
//const uint k = 20170906U;    // Today's date (use three days ago's dateif you want a prime)
//const uint k = 1664525U;     // Numerical Recipes

vec3 hash( uvec3 x )
{
    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;

    return vec3(x)*(1.0/float(0xffffffffU));
}


int xorshift(in int value) {
    // Xorshift*32
    // Based on George Marsaglia's work: http://www.jstatsoft.org/v08/i14/paper
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

int nextInt(inout int seed) {
    seed = xorshift(seed);
    return seed;
}


void main(void)
{
    vec3 final = hash(uvec3(gl_FragCoord.xy, SEED));
    gl_FragColor = vec4(final, 1.0);
}
