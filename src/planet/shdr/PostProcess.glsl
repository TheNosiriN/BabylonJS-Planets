precision highp float;
precision highp sampler2D;
precision highp sampler3D;


#extension GL_EXT_shader_texture_lod : enable
#extension GL_OES_standard_derivatives : enable


#include<Tools>
#include<Noise3D>



varying vec2 vUV;
uniform float TIME;
uniform sampler2D depthMap;
uniform sampler2D textureSampler;


struct Camera {
    vec3 position;
    vec3 direction;

    float fov;
    float far;
    float near;

    mat4 view;
    mat4 world;
    mat4 transform;
    mat4 projection;
};


struct Planet {
		vec3 position;
		float radius;
		float maxHeight;
};


// Uniforms
uniform vec2 screenSize;
uniform Camera camera;

uniform Planet planet;
uniform vec3 lightDir;


const int MAX_MARCHING_STEPS = 256;
const int MAX_SHADOW_STEPS = 32;
const float EPSILON = 0.01;





#include<PostProcessTools>



#include<PrecomputedAtmosphericScattering>
#include<Ocean>

vec3 combineScenes()
{
	vec3 screen = tex(vUV);
	float depth = texture2D(depthMap, vUV).r;

	float rdepth = remap(depth, 0.0, 1.0, camera.near, camera.far);
	rdepth = toWorldSpace(rdepth);

	vec3 eye = camera.position - planet.position;
	vec3 dir = getFragmentRay(gl_FragCoord.xy);


	vec2 calcPlanetSphere = raySphere(planet.position, planet.radius, eye, dir);
	float planetNoiseVal = fbm(normalize(eye + dir * min(calcPlanetSphere.x, rdepth))).x;
	float calcDepth = calcPlanetSphere.x - (planetNoiseVal * planet.radius * planet.maxHeight);
	/* calcDepth = min(calcDepth, rdepth); */
	vec3 calcPlanetPos = eye + dir * calcDepth - planet.position;


	vec3 color = screen;

	if (rdepth > planet.radius*4.0){
		color.xyz += pow(saturate(dot(dir, lightDir)), 1000.0);
	}
	color = Ocean(eye, dir, color, calcDepth, depth);
	color = Atmosphere(eye, dir, color, rdepth, depth);
	color = saturate(color);


	/* color += pow(flares(textureSampler, vUV, 0.1, 400.0, 0.4, 0.3), vec3(2.0)); */


	vec2 uv = vUV - 0.5;// * 2.0 - 1.0;
	uv.x *= screenSize.x/screenSize.y;

	vec3 sunpos = lightDir * planet.radius*1000.0;
	vec3 pCamera = (camera.transform * vec4(lightDir * planet.radius*1000.0, 1.0)).xyz;
	vec2 pScreen = pCamera.xy / pCamera.z;
	vec2 sunuv = pScreen * 0.5 + 0.5;


	vec3 sunvis = vec3(floor((1.0-0.1)+pow(tex(sunuv).r, 1.0)));

	sunuv = sunuv - 0.5;
	sunuv.x *= screenSize.x/screenSize.y;

	if (sunvis.r > 0.0){
		/* color.xyz += lensflare(uv*2.0, sunuv*2.0) * vec3(.8, .7, .3) * 3.0;//vec3(0.369,0.200,0.620) */
	}


	color = ACESFilm(color);//1.0 - exp(-1.0 * color);
	color = pow(color, vec3(1.0/2.2));

	return color;
}





void main(void)
{
		float marginSize = 0.1;
		if(vUV.y < marginSize || vUV.y > 1.0-marginSize){
				gl_FragColor = vec4(vec3(0.0), 1.0);
				return;
		}

		gl_FragColor = vec4(combineScenes(), 1.0);
		/* gl_FragColor = vec4(texture(textureSampler, vUV)); */
}
