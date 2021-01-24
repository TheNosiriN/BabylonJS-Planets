



/* #extension GL_EXT_shader_texture_lod : enable
#extension GL_OES_standard_derivatives : enable */


precision lowp float;
uniform sampler2D hashTexture;
const lowp int HASH_TEXTURE_WIDTH = 256;
uniform lowp int SEED;

const lowp int TABLE_SIZE = 256;
const lowp int TABLE_SIZE_MASK = TABLE_SIZE - 1;

uniform sampler2D permutationTexture;
const lowp int PERMUTATION_TEXTURE_HEIGHT = 16;
const lowp int PERMUTATION_TEXTURE_WIDTH = 32;



#ifndef PI
#define PI 3.14159265358979323846264338328
#define PHI 1.6180339887498948482045868343656
#endif


#define normalsScale 1.0

uniform lowp int octaves;
uniform lowp float frequency;
uniform lowp float amplitude;
uniform lowp float roughness;
uniform lowp float persistence;
uniform lowp float warpAmplitude;
uniform lowp float warpFrequency;



const mat3 M3 = mat3(0.00,0.80,0.60,-0.80,0.36,-0.48,-0.60,-0.48,0.64);
const mat2 M2 = mat2(0.8,-0.6,0.6,0.8);
lowp vec4 noised(vec3 pos);
float hash21Perm(ivec2 uv);
float hash31Perm(vec3 p);
vec4 getHashTex(vec2 uv);
vec4 getHashTex3(vec3 p);
float fbm21Tex(vec2 p);
float fbm31Tex(vec3 p);
vec3 hash33(vec3 p3);
float hash31(vec3 p);
float pnoise(vec3 p);
float tnoise(vec3 x);
vec3 voronoi( in vec3 x );






lowp vec4 fbm(vec3 coords)
{
    /* float f = frequency;
    float a = 0.5;

		float fn = 0.0;
		vec3 fd = vec3(0.0);
    vec3 dsum = vec3(0.0);

		vec3 pos = coords;

    for(int p = 0; p < octaves; p++)
    {
				lowp float val = cellular( coords ).x*2.0-1.0;
				//dsum += val;

				fn += val * a;

				a *= persistence;
        f *= roughness;

				//coords += 100.0;

				coords = M3*coords*roughness;
    }

		fn += snoise(coords)*a;
		return clamp(fn * fn * fn, -1.0, 1.0); */


		float f = 0.0;
    f  = 0.5000 * (cellular( coords ).x); coords = M3*coords*roughness;
    f += 0.2500 * (cellular( coords ).x); coords = M3*coords*roughness;
    f += 0.1250 * (cellular( coords ).x); coords = M3*coords*roughness;
    f += 0.0625 * (cellular( coords ).x);
		f = (f/0.9375);

		float ff = 0.0;
    ff  = 0.5000 * cellular( coords ).x*f; coords = M3*coords*roughness*2.0;
    ff += 0.2500 * cellular( coords ).x*f; coords = M3*coords*roughness*2.0;
    ff += 0.1250 * cellular( coords ).x*f; coords = M3*coords*roughness*2.0;
    ff += 0.0625 * cellular( coords ).x*f;
		ff = (ff/0.9375);

		float fn = (f) + (ff*ff*ff);
		return vec4(clamp(fn*2.0-1.0, -1.0, 1.0), 0,0,0);
}







float fbm21Tex(vec2 p)
{
	float f = 0.0;
	float w = float(HASH_TEXTURE_WIDTH);
  f += 0.5000 * getHashTex( p/w ).x; p = M2*p*2.02;
  f += 0.2500 * getHashTex( p/w ).x; p = M2*p*2.03;
  f += 0.1250 * getHashTex( p/w ).x; p = M2*p*2.01;
  f += 0.0625 * getHashTex( p/w ).x;
  return f/0.9375;
}

float fbm31Tex(vec3 p)
{
    float f = 0.0;
		float w = float(HASH_TEXTURE_WIDTH);
    f  = 0.5000 * getHashTex3( p/w ).x; p = M3*p*2.01;
    f += 0.2500 * getHashTex3( p/w ).x; p = M3*p*2.02;
    f += 0.1250 * getHashTex3( p/w ).x; p = M3*p*2.03;
    f += 0.0625 * getHashTex3( p/w ).x;
    return f;
}










lowp vec4 noised( in vec3 x )
{
    lowp vec3 i = floor(x);
    lowp vec3 w = fract(x);

		lowp vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
		lowp vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);


    lowp float a = hash31Perm(i+vec3(0.0,0.0,0.0));
    lowp float b = hash31Perm(i+vec3(1.0,0.0,0.0));
    lowp float c = hash31Perm(i+vec3(0.0,1.0,0.0));
    lowp float d = hash31Perm(i+vec3(1.0,1.0,0.0));
    lowp float e = hash31Perm(i+vec3(0.0,0.0,1.0));
		lowp float f = hash31Perm(i+vec3(1.0,0.0,1.0));
    lowp float g = hash31Perm(i+vec3(0.0,1.0,1.0));
    lowp float h = hash31Perm(i+vec3(1.0,1.0,1.0));

    lowp float k0 =   a;
    lowp float k1 =   b - a;
    lowp float k2 =   c - a;
    lowp float k3 =   e - a;
    lowp float k4 =   a - b - c + d;
    lowp float k5 =   a - c - e + g;
    lowp float k6 =   a - b - e + f;
    lowp float k7 = - a + b + c - d + e - f - g + h;

    return vec4( k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z,
                 du * vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                            k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                            k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}








vec3 voronoi( in vec3 x )
{
    vec3 p = floor( x );
    vec3 f = fract( x );

	float id = 0.0;
    vec2 res = vec2( 100.0 );
    for( int k=-1; k<=1; k++ )
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        vec3 b = vec3( float(i), float(j), float(k) );
        vec3 r = vec3( b ) - f + hash31Perm( p + b );
        float d = dot( r, r );

        if( d < res.x )
        {
			id = dot( p+b, vec3(1.0,57.0,113.0 ) );
            res = vec2( d, res.x );
        }
        else if( d < res.y )
        {
            res.y = d;
        }
    }

    return vec3( sqrt( res ), abs(id) );
}














vec3 hash33(vec3 p3)
{
    p3 = fract(p3 * vec3(.1031,.11369,.13787));
    p3 += dot(p3, p3.yxz+19.19);
    return -1.0 + 2.0 * fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float hash31(vec3 p)
{
    p = 50.0*fract( p*0.3183099 + vec3(0.71,0.113,0.419));
    return -1.0+2.0*fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float hash31Perm(vec3 p)
{
	int x = int(p.x) & TABLE_SIZE_MASK;
	int y = int(p.y) & TABLE_SIZE_MASK;
	int z = int(p.z) & TABLE_SIZE_MASK;
	//int perm = permutationTable[permutationTable[permutationTable[x] + y] + z];
	float perm = arrayTexture2D(permutationTexture, x, PERMUTATION_TEXTURE_WIDTH).x * float(TABLE_SIZE_MASK);
	perm = arrayTexture2D(permutationTexture, int(perm) + y, PERMUTATION_TEXTURE_WIDTH).x * float(TABLE_SIZE_MASK);
	perm = arrayTexture2D(permutationTexture, int(perm) + z, PERMUTATION_TEXTURE_WIDTH).x;
	return -1.0 + 2.0 * perm;
}


float hash21Perm(ivec2 uv)
{
	int x = uv.x & TABLE_SIZE_MASK;
	int y = uv.y & TABLE_SIZE_MASK;
	/* int perm = permutationTable[permutationTable[x] + y];
	return -1.0 + 2.0 * (float(perm)/float(TABLE_SIZE_MASK)); */
	float perm = arrayTexture2D(permutationTexture, x, PERMUTATION_TEXTURE_WIDTH).x * float(TABLE_SIZE_MASK);
	perm = arrayTexture2D(permutationTexture, int(perm) + y, PERMUTATION_TEXTURE_WIDTH).x;
	return -1.0 + 2.0 * perm;
}


vec4 getHashTex(vec2 uv){
	return texture(hashTexture, uv);
}
vec4 getHashTex3(vec3 p){
	vec3 n = normalize(p);
	return (
		getHashTex(p.xy).rgba*n.z*n.z
		+getHashTex(p.zy).rgba*n.x*n.x
		+getHashTex(p.xz).rgba*n.y*n.y
	);
}










const ivec2 zOffset = ivec2(37,17);
float tnoise(vec3 x)
{
	ivec3 i = ivec3(floor(x));
	vec3 f = fract(x);
	f = f*f*f*(f*(f*6.0-15.0)+10.0);

	ivec2 uv = i.xy + zOffset*i.z;
	vec2 rgA = vec2( hash21Perm(uv+ivec2(0,0)), hash21Perm(uv+ivec2(0,0)+zOffset) );
	vec2 rgB = vec2( hash21Perm(uv+ivec2(1,0)), hash21Perm(uv+ivec2(1,0)+zOffset) );
	vec2 rgC = vec2( hash21Perm(uv+ivec2(0,1)), hash21Perm(uv+ivec2(0,1)+zOffset) );
	vec2 rgD = vec2( hash21Perm(uv+ivec2(1,1)), hash21Perm(uv+ivec2(1,1)+zOffset) );
	vec2 rg = mix( mix( rgA, rgB, f.x ),
								 mix( rgC, rgD, f.x ), f.y );
	return mix( rg.x, rg.y, f.z );
}
