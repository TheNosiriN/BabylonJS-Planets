

precision highp float;
#include<Tools>
#include<Noise3D>



precision highp float;




// Varying
varying vec3 vPosition;
varying vec3 vNormal;

// Uniforms
uniform mat4 world;
uniform lowp float maxHeight;
uniform lowp float radius;

uniform vec3 lightDir;
uniform vec3 cameraPosition;


uniform sampler2D grassTexture[5];
uniform sampler2D rockTexture[5];





const float textureScale = 10000.0;
const float weightsSharpness = 40.0;



#define SC (250.0)

struct HeightColor {
	vec3 diffuse;
	vec3 normal;
};





vec3 makeRock(vec3 p, vec3 n)
{
	vec3 rock;
	float r = getHashTex3((7.0/SC)*p/256.0 ).x;
	rock = (r*0.25+0.75)*0.9*mix(
		vec3(0.08,0.05,0.03), vec3(0.10,0.09,0.08),
		getHashTex3(0.00007*vec3(p.x,p.y*48.0,p.z*96.0)/1.0).x
	);
	rock = mix( rock, 0.20*vec3(0.45,.30,0.15)*(0.50+0.50*r),smoothstep(0.70,0.9,n.y) );
	rock = mix( rock, 0.15*vec3(0.30,.30,0.10)*(0.25+0.75*r),smoothstep(0.95,1.0,n.y) );
	rock *= 0.1+1.8*sqrt(fbm31Tex(p*0.04)*fbm31Tex(p*0.005));

	return rock;
}

vec3 makeSnow(vec3 p, vec3 n)
{
	vec3 snow;
	float h = smoothstep(55.0,80.0,p.y/SC + 25.0*fbm31Tex(0.01*p/SC) );
	float e = smoothstep(1.0-0.5*h,1.0-0.1*h,n.y);
	float o = 0.3 + 0.7*smoothstep(0.0,0.1,n.x+h*h);
	float s = h*e*o;
	snow = mix( vec3(1.0), 0.29*vec3(0.62,0.65,0.7), smoothstep( 0.1, 0.9, s ) );

	return snow;
}




HeightColor makeSnowHeightColor(vec3 fp, vec3 rp, vec3 fn, vec3 rn)
{
	HeightColor col;
	float n = fbm31Tex(rp*65536.0);

	vec3 texPos = vPosition/radius;
	vec3 top = makeSnow(rp, rn);//triplanarMap(grassTexture[0], texPos, flatNormal, textureScale);
	vec3 side = mix(
		makeRock(rp, rn),
		triplanarMap(rockTexture[0], texPos, fn, textureScale),
		n
	);
	vec3 topN = triplanarMap(rockTexture[1], texPos, rn, textureScale);
	vec3 sideN = triplanarMap(rockTexture[1], texPos, rn, textureScale);

	float deform = (n * 2.0 - 1.0) * 5.0;//(textureScale/(SC*2.0));
	fn = normalize(fn+deform);
	col.diffuse = triplanarWeights(side, top, side, fn, weightsSharpness);
	col.normal = triplanarWeights(sideN, topN, sideN, fn, weightsSharpness);

	return col;
}




HeightColor makeRockGrassHeightColor(vec3 fp, vec3 rp, vec3 fn, vec3 rn)
{
	HeightColor col;

	vec3 texPos = vPosition/radius;
	vec3 top = mix(
		makeRock(rp, rn),
		triplanarMap(grassTexture[0], texPos, fn, textureScale),
		fbm31Tex(rp*655366.0)
	);
	vec3 side = top;
	vec3 topN = triplanarMap(rockTexture[1], texPos, rn, textureScale);
	vec3 sideN = triplanarMap(rockTexture[1], texPos, rn, textureScale);

	/* float deform = (fbm31Tex(rp.xz*30.0) * 2.0 - 1.0) * (radius-textureScale);
	fn = normalize(fn+deform); */
	col.diffuse = triplanarWeights(side, top, side, fn, weightsSharpness);
	col.normal = triplanarWeights(sideN, topN, sideN, fn, weightsSharpness);

	return col;
}



const float theta = 0.0001;
vec3 calculateNormal(vec3 p, float origin)
{
	vec2 sph = vectorToSpherical(normalize(p));
	vec3 scx = normalize(sphericalToVector(sph.x+theta, sph.y));
	vec3 scy = normalize(sphericalToVector(sph.x, sph.y+theta));
	float dfx = fbm(scx).x;
	float dfy = fbm(scy).x;

	return normalize(cross(
		( scx * (radius + (dfx * radius * maxHeight)) ) - p,
		( scy * (radius + (dfy * radius * maxHeight)) ) - p
	));

	/* vec3 P = vec3(-4, 4, 0) * 0.01;

	vec3 B = vec3(
			fbm(normalize(p+P.xzz)),
			fbm(normalize(p+P.zxz)),
			fbm(normalize(p+P.zzx))
	) - origin;

	vec3 N = normalize(p);
	B = (B-N*dot(B,N));
	return normalize(N+B); */
}




void main(void)
{
		vec3 vOriginalPos = normalize(vPosition);
		float noiseVal = fbm(vOriginalPos).x;


		vec3 flatPos = vec3(vOriginalPos.x, 1.0, vOriginalPos.z) * (radius + (noiseVal * radius * maxHeight));
		vec3 flatNormal = normalize(vec3(vOriginalPos.x, 1.0, vOriginalPos.z) + normalize(cross( dFdy(flatPos), dFdx(flatPos) )));

		vec3 roundPos = vOriginalPos * (radius + (noiseVal * radius * maxHeight));
		vec3 roundNormal = normalize(vOriginalPos + normalize(cross( dFdy(roundPos), dFdx(roundPos) )));

		flatNormal = roundNormal;

		//vec3 norm = normalize(vOriginalPos + noiseVal.yzw);
		/* float deform = fbm31Tex((roundPos/radius)*80000.0);
		flatNormal = flatNormal + deform;
		roundNormal = roundNormal + deform; */
		HeightColor snow = makeSnowHeightColor(flatPos/radius, roundPos/radius, flatNormal, roundNormal);
		HeightColor rock = makeRockGrassHeightColor(flatPos/radius, roundPos/radius, flatNormal, roundNormal);

		vec3 diffuse = mix(rock.diffuse, snow.diffuse, saturate(noiseVal/2.0));

		/* vec3 beach = vec3(0.761, 0.698, 0.502);
		vec3 grass = vec3(0.1, 0.5, 0.2);

		diffuse = mix(diffuse, beach, smoothstep(0.01, 0.0, noiseVal));
		diffuse = mix(diffuse, grass, smoothstep(0.01, 0.0, noiseVal)*smoothstep(0.5, 0.01, noiseVal)); */

		/* vec3 normal = mix(
			triplanarNormal(rockTexture[0], roundPos, roundNormal, 5.0, 10.0),
			triplanarNormal(grassTexture[0], roundPos, roundNormal, 5.0, 10.0),
			saturate(noiseVal)
		); */
		vec3 normal = roundNormal;

		vec3 color = diffuse;

    // World values
    vec3 vPositionW = vec3(world * vec4(vPosition, 1.0));
    vec3 vNormalW = normalize(vec3(world * vec4(normal, 1.0)));

    // diffuse
    float ndl = saturate(dot(normal, lightDir));// * saturate(dot(normalize(vPosition), lightDir));

    gl_FragColor = vec4(color * ndl, 1.);
}
